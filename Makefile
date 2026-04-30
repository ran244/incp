NAME    = inception
COMPOSE = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/$(USER)/data

all: up

prepare:
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

up: prepare
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --remove-orphans
	docker image prune -f

fclean: clean
	$(COMPOSE) down -v --remove-orphans
	docker system prune -af --volumes
	sudo rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

re: fclean up

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

.PHONY: all prepare up down clean fclean re ps logs
