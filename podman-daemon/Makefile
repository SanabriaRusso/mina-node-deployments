.DEFAULT_GOAL := help
SHELL := /bin/bash
.PHONY: help

# ── Network Registry ─────────────────────────────────────────────
# To add a network: add its name to NETWORKS and define OVERLAY_<name>.
# The env file is auto-derived as env/<name>.env.

NETWORKS := mesa pre-mesa devnet mainnet mainnet-uptime

OVERLAY_mesa           := daemon-full
OVERLAY_pre-mesa       := daemon-full
OVERLAY_devnet         := daemon
OVERLAY_mainnet        := daemon
OVERLAY_mainnet-uptime := daemon-uptime

# ── Compose Command Builder ─────────────────────────────────────
BASE_FILE := podman-compose.yml
COMPOSE   := podman-compose

compose-cmd = $(COMPOSE) -f $(BASE_FILE) -f podman-compose.$(OVERLAY_$(1)).yml --env-file env/$(1).env

# ── Target Generator ────────────────────────────────────────────
define NETWORK_TARGETS

.PHONY: up-$(1) down-$(1) logs-$(1) config-$(1) restart-$(1) ps-$(1)

up-$(1):
	$(call compose-cmd,$(1)) up -d

down-$(1):
	$(call compose-cmd,$(1)) down

logs-$(1):
	$(call compose-cmd,$(1)) logs -f

config-$(1):
	$(call compose-cmd,$(1)) config

restart-$(1):
	$(call compose-cmd,$(1)) restart

ps-$(1):
	$(call compose-cmd,$(1)) ps

endef

$(foreach net,$(NETWORKS),$(eval $(call NETWORK_TARGETS,$(net))))

# ── Ledger Generation ───────────────────────────────────────────
# Runs in foreground (no -d) since it's a one-shot job.
# Override LEDGER_NETWORK to use a different env file.
# Override LEDGER_PREFIX to change the output filename prefix.

LEDGER_NETWORK := devnet
# Genesis timestamp: next full hour from now (macOS-compatible date)
GENESIS_TIMESTAMP ?= $(shell date -u -v+1H '+%Y-%m-%dT%H:00:00Z')
export GENESIS_TIMESTAMP

ledger-gen-cmd = $(COMPOSE) -f $(BASE_FILE) -f podman-compose.ledger-gen.yml --env-file env/$(LEDGER_NETWORK).env

.PHONY: ledger-gen ledger-gen-config ledger-gen-down combine-keys

ledger-gen:
	$(call ledger-gen-cmd) up

ledger-gen-config:
	$(call ledger-gen-cmd) config

ledger-gen-down:
	$(call ledger-gen-cmd) down

combine-keys:
	./process-keys.sh output

# ── Help ─────────────────────────────────────────────────────────
help:
	@echo "Mina Node Deployment - podman-compose runner"
	@echo ""
	@echo "Available networks: $(NETWORKS)"
	@echo ""
	@echo "Commands:"
	@echo "  make up-<network>       Start daemon (detached)"
	@echo "  make down-<network>     Stop and remove daemon"
	@echo "  make logs-<network>     Tail daemon logs"
	@echo "  make config-<network>   Print resolved compose config"
	@echo "  make restart-<network>  Restart daemon"
	@echo "  make ps-<network>       Show running containers"
	@echo ""
	@echo "Ledger generation:"
	@echo "  make ledger-gen                       Generate genesis ledger (foreground)"
	@echo "  make ledger-gen LEDGER_PREFIX=mynet    Override output prefix"
	@echo "  make ledger-gen LEDGER_NETWORK=mesa    Use a different network env"
	@echo "  make ledger-gen-config                 Preview resolved ledger-gen config"
	@echo "  make ledger-gen-down                   Clean up ledger-gen container"
	@echo "  make combine-keys                     Combine and escape all key pairs"
	@echo ""
	@echo "Examples:"
	@echo "  make up-mesa            Start mesa daemon"
	@echo "  make config-devnet      Preview resolved devnet config"
	@echo "  make logs-mainnet       Follow mainnet logs"
	@echo "  make ledger-gen         Generate ledger with devnet env"
	@echo ""
	@echo "Network -> Overlay mapping:"
	@$(foreach net,$(NETWORKS),echo "  $(net) -> podman-compose.$(OVERLAY_$(net)).yml";)
