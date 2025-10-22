.PHONY: up down produce consume audit
up:
	docker compose up -d

down:
	docker compose down -v

produce:
	python3 services/producer/produce_events.py

consume:
	python3 services/consumer/consume_events.py

audit:
	python3 services/auditor/verify_audit_chain.py
