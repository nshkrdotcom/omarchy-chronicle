SHELL := /bin/bash
.PHONY: test test-python test-js test-qml lint check demo
test-python:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
test-js:
	node --test tests/js/*.test.js
test-qml:
	QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests/qml -import tests/support
test: test-python test-js
lint:
	python3 scripts/lint.py
check: test test-qml lint
demo:
	QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /usr/lib/qt6/bin/qmltestrunner -input tests/qml_preview -import tests/support
