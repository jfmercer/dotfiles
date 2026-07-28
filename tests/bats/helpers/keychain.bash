# A fake `security` for testing bin/secret.
#
# Two reasons this is not optional. First, `security` is macOS-only, so without a
# stub none of bin/secret could be tested on the Ubuntu half of the CI matrix.
# Second, the real one writes to the developer's actual login keychain -- a test
# suite must not be able to touch that even by accident, which is also why every
# suite sets $SECRET_ACCOUNT and $SECRET_ENV_NAME to throwaway values.
#
# The fake keychain is a directory of files named <account>__<service>, each
# holding the raw value with no trailing newline. It implements the three
# subcommands bin/secret uses and mimics their exit codes.

install_fake_security() {
    FAKE_KEYCHAIN="$BATS_TEST_TMPDIR/keychain"
    mkdir -p "$FAKE_KEYCHAIN"
    export FAKE_KEYCHAIN

    make_stub security <<'STUB'
set -u

cmd="${1:-}"
shift || true

account=""; service=""; value=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -a) account="$2"; shift 2 ;;
        -s) service="$2"; shift 2 ;;
        # -w carries the password for add-generic-password but is a bare
        # "print the password only" flag for find-generic-password.
        -w) if [ "$cmd" = add-generic-password ]; then
                value="$2"; shift 2
            else
                shift
            fi ;;
        *)  shift ;;
    esac
done

item="$FAKE_KEYCHAIN/${account}__${service}"
printf '%s %s %s\n' "$cmd" "$account" "$service" >>"$STUB_LOG"

# 44 is what the real security exits with for a missing item.
not_found() {
    echo "security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain." >&2
    exit 44
}

case "$cmd" in
    find-generic-password)
        [ -f "$item" ] || not_found
        # The real command terminates the value with a newline.
        printf '%s\n' "$(cat "$item")"
        ;;
    add-generic-password)
        printf '%s' "$value" >"$item"
        ;;
    delete-generic-password)
        [ -f "$item" ] || not_found
        rm -f "$item"
        ;;
    *)
        echo "fake security: unhandled subcommand '$cmd'" >&2
        exit 2
        ;;
esac
STUB
}

# Put a value into the fake keychain without going through `secret set`.
# `set` reads with `read -r`, which cannot carry an embedded newline, so seeding
# directly is the only way to test that such a value survives the bundle.
seed_secret() {
    local service="$1" value="$2"
    printf '%s' "$value" >"$FAKE_KEYCHAIN/${SECRET_ACCOUNT}__${service}"
}

# Did anything try to write to the keychain?
assert_no_writes() {
    if grep -q '^add-generic-password' "$STUB_LOG"; then
        printf 'expected no keychain writes, but got:\n%s\n' "$(cat "$STUB_LOG")" >&2
        return 1
    fi
}
