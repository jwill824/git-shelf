package tui

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Action represents the user's resolution choice for a conflict.
type Action int

const (
	ActionKeepMine   Action = iota // restore personal blob
	ActionTakeTheirs               // update shelf to upstream version
	ActionShowDiff                 // show git diff output
	ActionOpenEditor               // open editor for manual resolution
)

// Conflict describes one shelved file that has diverged upstream.
type Conflict struct {
	Path         string
	PersonalBlob string
	UpstreamBlob string
}

// Resolution is the user's decision for one conflict.
type Resolution struct {
	Conflict Conflict
	Action   Action
}

var (
	titleStyle  = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("214"))
	activeStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("86")).Bold(true)
	dimStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
	choices     = []string{"Keep mine", "Take theirs", "Show diff", "Open editor"}
)

type conflictModel struct {
	conflict Conflict
	cursor   int
	done     bool
	action   Action
}

func (m conflictModel) Init() tea.Cmd { return nil }

func (m conflictModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(choices)-1 {
				m.cursor++
			}
		case "enter", " ":
			m.action = Action(m.cursor)
			m.done = true
			return m, tea.Quit
		case "q", "ctrl+c":
			m.action = ActionKeepMine
			m.done = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m conflictModel) View() string {
	var b strings.Builder
	fmt.Fprintf(&b, "%s %s\n\n", titleStyle.Render("⚠  Shelf conflict:"), m.conflict.Path)
	fmt.Fprintln(&b, dimStyle.Render("   Upstream changed this file while you had it shelved.\n"))
	for i, choice := range choices {
		cursor := "  "
		style := dimStyle
		if i == m.cursor {
			cursor = "↑ "
			style = activeStyle
		}
		fmt.Fprintf(&b, " %s%s\n", cursor, style.Render(choice))
	}
	fmt.Fprintln(&b, dimStyle.Render("\n  ↑/↓ navigate · enter select · q keep mine"))
	return b.String()
}

// RunConflictUI presents an interactive prompt for each conflict.
// Opens /dev/tty directly so it works from git hooks where stdin is closed.
func RunConflictUI(conflicts []Conflict) ([]Resolution, error) {
	tty, err := os.Open("/dev/tty")
	if err != nil {
		return nil, fmt.Errorf("open tty: %w", err)
	}
	defer tty.Close()

	var resolutions []Resolution
	for _, c := range conflicts {
		m := conflictModel{conflict: c}
		p := tea.NewProgram(m, tea.WithInput(tty))
		result, err := p.Run()
		if err != nil {
			return nil, fmt.Errorf("tui: %w", err)
		}
		final := result.(conflictModel)

		if final.action == ActionShowDiff {
			showDiff(c)
			// Re-run prompt after showing diff
			p2 := tea.NewProgram(conflictModel{conflict: c}, tea.WithInput(tty))
			result2, err := p2.Run()
			if err != nil {
				return nil, err
			}
			final = result2.(conflictModel)
		}

		resolutions = append(resolutions, Resolution{Conflict: c, Action: final.action})
	}
	return resolutions, nil
}

func showDiff(c Conflict) {
	cmd := exec.Command("git", "diff", c.PersonalBlob, c.UpstreamBlob)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
}

// OpenEditorForConflict writes both versions to temp files and opens $EDITOR.
// Returns the path to the user-edited result file.
func OpenEditorForConflict(c Conflict, personalContent, upstreamContent []byte) ([]byte, error) {
	mine, err := os.CreateTemp("", "shelf-mine-*")
	if err != nil {
		return nil, err
	}
	defer os.Remove(mine.Name())
	mine.Write(personalContent)
	mine.Close()

	theirs, err := os.CreateTemp("", "shelf-theirs-*")
	if err != nil {
		return nil, err
	}
	defer os.Remove(theirs.Name())
	theirs.Write(upstreamContent)
	theirs.Close()

	editor := os.Getenv("GIT_EDITOR")
	if editor == "" {
		editor = os.Getenv("EDITOR")
	}
	if editor == "" {
		editor = "vi"
	}

	cmd := exec.Command(editor, mine.Name())
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("editor: %w", err)
	}
	return os.ReadFile(mine.Name())
}
