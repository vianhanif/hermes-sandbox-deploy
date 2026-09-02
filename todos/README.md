# Todos kanban convention

One `.md` file = one task. Status lives in YAML front-matter:

- `status: todo` — backlog
- `status: doing` — in progress
- `status: done` — completed
- `status: blocked` — waiting on something

Move a task by editing its `status` field and committing. Optional `priority: high|med|low` for ordering.