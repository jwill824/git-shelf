.PHONY: test install-dev

SHELL := /bin/zsh

test:
	bats tests/

install-dev:
	chmod +x bin/git-cloak
	@echo "Dev install complete. Add '$(PWD)/bin' to PATH or add 'PATH_add bin' to .envrc"
