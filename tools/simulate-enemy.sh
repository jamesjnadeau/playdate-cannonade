#!/usr/bin/env bash
# Convenience wrapper around simulate.sh that boots straight into
# EnemySelectScene, for quickly testing a single enemy's behavior/appearance
# without navigating there through the title menu each time.
MERMAID_START_SCENE=EnemySelect exec ./tools/simulate.sh
