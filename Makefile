.PHONY: test

test:
	swift test

test-linux:
	swift test --enable-test-discovery