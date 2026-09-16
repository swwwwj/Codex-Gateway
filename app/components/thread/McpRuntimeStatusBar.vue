<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { PlugZapIcon } from "@lucide/vue";
import { Badge } from "@codex-gateway/ui/badge";
import { useGatewayMcpRuntimeStore } from "@/stores/gateway-mcp-runtime";
import { pinnedKey } from "@/stores/gateway/thread-utils/identity";

const props = defineProps<{ hostId: number | null; threadId: string }>();
const runtime = useGatewayMcpRuntimeStore();
const servers = computed(() =>
  props.hostId === null
    ? []
    : (runtime.serversByThreadKey[pinnedKey(props.hostId, props.threadId)] ?? []),
);
const attention = computed(() =>
  servers.value.filter(
    (server) =>
      server.runtimeStatus === "authenticationRequired" || server.runtimeStatus === "failed",
  ),
);

const refreshing = ref(false);
const statusLabels: Record<string, string> = {
  notStarted: "未启动",
  starting: "连接中",
  authenticationRequired: "需要登录",
  failed: "连接失败",
  cancelled: "已取消",
};

async function refresh() {
  if (props.hostId === null || refreshing.value) return;
  refreshing.value = true;
  try {
    await runtime.refreshStatuses(props.hostId, props.threadId);
  } finally {
    refreshing.value = false;
  }
}

watch(
  () => [props.hostId, props.threadId] as const,
  ([hostId, threadId]) => {
    if (hostId !== null) void runtime.refreshStatuses(hostId, threadId);
  },
  { immediate: true },
);
</script>

<template>
  <div
    v-if="attention.length"
    class="flex min-h-9 shrink-0 items-center gap-2 overflow-x-auto border-b border-hairline bg-canvas-soft/55 px-3 text-xs"
    data-testid="mcp-runtime-status"
  >
    <PlugZapIcon class="size-3.5 shrink-0 text-ink-muted" />
    <span class="shrink-0 font-medium text-ink-muted">{{ $t("app.mcpConnections") }}</span>
    <Badge
      v-for="server in attention"
      :key="server.name"
      :variant="server.runtimeStatus === 'failed' ? 'destructive' : 'outline'"
      class="shrink-0"
    >
      {{ server.name }} · {{ statusLabels[server.runtimeStatus || ""] || server.runtimeStatus }}
    </Badge>
    <button
      type="button"
      class="ml-auto shrink-0 rounded px-2 py-1 text-ink-muted hover:bg-canvas-soft hover:text-ink disabled:opacity-50"
      :disabled="refreshing"
      @click="refresh"
    >
      {{ refreshing ? "检查中…" : "重试" }}
    </button>
  </div>
</template>
