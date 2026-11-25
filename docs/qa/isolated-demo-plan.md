# Isolated software demo Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Run a separate Windows QA backend, database and broker without changing existing services.
**Architecture:** Validate ports before constructing services. Share small PowerShell guards. Store only resource identity in QA state; credentials remain in process memory.
**Tech Stack:** C++20, PowerShell 7, PostgreSQL 17, Mosquitto 2, Docker Desktop.
**Spec:** User request, Issue #61 (Refs #29, #59).

## Global constraints
No changes to PR #58/#60, existing containers, secrets, Firebase, firmware or Flutter code. No merge/deploy.

## Review focus
Invalid ports must fail before connecting; URL redirects must not escape loopback; remote Docker env/context must fail; resource identity must match before stop; partially failed startup must remain recoverable.

## A — backend configuration
- [ ] Add runtime_config_test.cpp, observe missing header, implement config/RuntimeConfig.h, wire main.cpp and CMake.
- [ ] Run CMake, build and CTest; commit configuration.

## B — existing scripts
- [ ] Add qa_helpers.ps1 guards and behavioral tests, update four existing entry points.
- [ ] Check defaults, invalid API URLs, container names and Docker endpoints; commit scripts.

## C — isolated services
- [ ] Add start_isolated_qa.ps1 / stop_isolated_qa.ps1, named/labeled containers and process identity state without secrets.
- [ ] Verify occupied ports, wrong owner and cleanup; commit lifecycle.

## D — local acceptance
- [ ] Run real authenticated door smoke twice, review original container inventory, document actual results and commands.
- [ ] Commit docs, diff check, push once and create Draft PR, inspect CI.
