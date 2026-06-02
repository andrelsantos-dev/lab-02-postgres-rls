.PHONY: help up down logs health reset
.DEFAULT_GOAL := help

help: ##Available commands:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)


up: ## Start PostgreSQL.
	docker compose up -d

down: ## Stop PostgreSQL.
	docker compose down

logs: ## Show PostgreSQL logs.
	docker compose logs -f

health: ## Check PostgreSQL health.
	@docker exec postgres-rls-lab pg_isready -U postgres -d rls_lab \
	&& echo "✅ PostgreSQL is healthy" \
	|| echo "❌ PostgreSQL is unavailable"

reset: ## Recreate environment.
	docker compose down -v
	$(MAKE) up

psql: ## Connect to PostgreSQL.
	docker exec -it postgres-rls-lab psql -U postgres -d rls_lab

status: ## Show container status.
	docker compose ps