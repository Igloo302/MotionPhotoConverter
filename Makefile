REPO_NAME := $(notdir $(CURDIR))
WORKTREE_ROOT := $(dir $(CURDIR))$(REPO_NAME)-worktrees
TASK_NAME := $(or $(name),$(NAME))

.PHONY: wt clean-wt

wt:
	@if [ -z "$(TASK_NAME)" ]; then \
		echo "Usage: make wt name=<task-slug>"; \
		exit 1; \
	fi
	@mkdir -p "$(WORKTREE_ROOT)"
	@if git show-ref --verify --quiet "refs/heads/feat/$(TASK_NAME)"; then \
		git worktree add "$(WORKTREE_ROOT)/$(TASK_NAME)" "feat/$(TASK_NAME)"; \
	else \
		git worktree add -b "feat/$(TASK_NAME)" "$(WORKTREE_ROOT)/$(TASK_NAME)"; \
	fi
	@if [ -f "$(CURDIR)/.env" ]; then \
		ln -sf "$(CURDIR)/.env" "$(WORKTREE_ROOT)/$(TASK_NAME)/.env"; \
		echo "Linked .env -> $(WORKTREE_ROOT)/$(TASK_NAME)/.env"; \
	fi
	@echo "Worktree ready: $(WORKTREE_ROOT)/$(TASK_NAME) (branch: feat/$(TASK_NAME))"

clean-wt:
	@if [ -z "$(TASK_NAME)" ]; then \
		echo "Usage: make clean-wt name=<task-slug>"; \
		exit 1; \
	fi
	@if [ -d "$(WORKTREE_ROOT)/$(TASK_NAME)" ]; then \
		git worktree remove "$(WORKTREE_ROOT)/$(TASK_NAME)"; \
	else \
		echo "Worktree not found: $(WORKTREE_ROOT)/$(TASK_NAME)"; \
	fi
	@if git show-ref --verify --quiet "refs/heads/feat/$(TASK_NAME)"; then \
		git branch -d "feat/$(TASK_NAME)"; \
	fi
