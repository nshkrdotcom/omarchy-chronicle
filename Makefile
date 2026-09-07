SHELL := /bin/bash
.PHONY: test test-python test-js test-qml lint check demo
test-python:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
test: test-python
