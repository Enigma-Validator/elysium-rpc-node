.PHONY: up down restart logs status update

up:
	@test -f .env || cp .env.example .env
	docker compose up -d --build

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f --tail 100

status:
	@./scripts/status.sh --watch

update:
	git pull
	docker compose up -d --build
