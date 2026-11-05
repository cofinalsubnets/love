// test/thumb2/perf/insn.c -- a qemu plugin: the guest instructions a run executes, to stderr at exit.
// load it with qemu's -plugin; perf.sh meter builds it
#include <qemu-plugin.h>
#include <stdio.h>
QEMU_PLUGIN_EXPORT int qemu_plugin_version = QEMU_PLUGIN_VERSION;
static void trans(struct qemu_plugin_tb *tb, void *sb) {
 qemu_plugin_u64 n = qemu_plugin_scoreboard_u64(sb);
 for (size_t i = 0; i < qemu_plugin_tb_n_insns(tb); i++)
  qemu_plugin_register_vcpu_insn_exec_inline_per_vcpu(
   qemu_plugin_tb_get_insn(tb, i), QEMU_PLUGIN_INLINE_ADD_U64, n, 1); }
static void bye(void *sb) {
 fprintf(stderr, "insns %llu\n", (unsigned long long) qemu_plugin_u64_sum(qemu_plugin_scoreboard_u64(sb))); }
QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id, const qemu_info_t *info, int argc, char **argv) {
 struct qemu_plugin_scoreboard *sb = qemu_plugin_scoreboard_new(sizeof(uint64_t));
 qemu_plugin_register_vcpu_tb_trans_cb(id, trans, sb);
 qemu_plugin_register_atexit_cb(id, bye, sb);
 return 0; }
