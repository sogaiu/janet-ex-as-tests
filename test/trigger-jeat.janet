# this is meant to be executed from the repository root directory

# when this file is executed via jpm test / jeep test, the current
# working directory is one level up, i.e. it's the repository root
# (eprintf "cwd: %s" (os/cwd))

# this path is relative to test dir
(import ../jeat)

(jeat/main nil `{:via-test-trigger true}`)

