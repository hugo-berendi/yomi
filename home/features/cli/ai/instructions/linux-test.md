Before tests needing system packages, services, containers, browsers or substantial
resources, use the linux-test-environment skill when available. Prefer the managed
test VM for disruptive or heavy tests; keep small ordinary checks local. Discover
its identity and readiness with t3code-test status. Inside the guest, execute there
instead of delegating recursively. Test the exact revision and working-tree changes.
Follow current T3 orchestration and provider-routing rules. An unavailable guest
does not authorize disruptive tests on the production host. Guest permissions do
not grant production-host permissions, and Ubuntu checks do not replace required
NixOS evaluation/build checks.
