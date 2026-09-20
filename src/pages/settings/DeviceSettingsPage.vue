<template>
  <div class="settings-section">
    <h3 class="section-title">设备信息</h3>

    <div class="setting-group">
      <h4 class="group-title">当前状态</h4>
      <div class="status-box">
        <div class="status-row">
          <span class="status-key">登录状态</span>
          <span :class="['status-value', deviceInfo?.loggedIn ? 'status-on' : 'status-off']">
            {{ deviceInfo?.loggedIn ? '已登录（设备码固定）' : '未登录（设备码随机）' }}
          </span>
        </div>
        <div class="status-row">
          <span class="status-key">数字联盟ID</span>
          <span :class="['status-value', deviceInfo?.szlmActive ? 'status-on' : '']">
            {{ deviceInfo?.szlmActive ? '已生效（覆盖默认设备码）' : '未设置' }}
          </span>
        </div>
        <div class="status-row">
          <span class="status-key">设备码来源</span>
          <span
            :class="[
              'status-value',
              deviceInfo?.codeSource === 'szlm' || deviceInfo?.codeSource === 'random' ? 'status-on' : '',
            ]"
          >
            {{ codeSourceLabel }}
          </span>
        </div>
        <div class="status-row">
          <span class="status-key">设备码（X-App-Device）</span>
          <code class="status-code" :title="deviceInfo?.deviceCode">{{ deviceInfo?.deviceCode || '加载中...' }}</code>
        </div>
        <p class="tray-tip">
          <i class="fas fa-info-circle"></i>
          未登录时设备码为随机生成（每台电脑首次生成后固定）；登录后使用账号绑定的固定设备码（默认与 SDK 官方一致，可被写操作校验通过），请勿手动修改。填写下方数字联盟ID后，设备码将以该 ID 重新生成并覆盖以上默认行为，也可随时随机重掷设备码。
        </p>
      </div>
    </div>

    <div class="setting-group">
      <h4 class="group-title">数字联盟ID</h4>
      <div class="setting-row">
        <div class="row-info">
          <span class="row-label">数字联盟ID</span>
          <span class="row-sub">填写自己手机的数字联盟 ID，修复评论、发帖等写操作校验；留空使用默认设备码</span>
        </div>
        <div class="szlm-actions">
          <input
            v-model="settingsStore.settings.deviceFingerprint.szlmId"
            type="text"
            class="text-input szlm-input"
            placeholder="留空使用默认设备码"
            maxlength="64"
            spellcheck="false"
          />
          <button
            class="action-button compact"
            :disabled="verifying || !fingerprint.szlmId.trim()"
            @click="verifySzlm"
          >
            <i :class="verifying ? 'fas fa-spinner fa-spin' : 'fas fa-check'"></i>
            {{ verifying ? '验证中' : '验证' }}
          </button>
        </div>
      </div>
      <p v-if="verifyResult" :class="['verify-result', verifyResult.ok ? 'ok' : 'fail']">
        <i :class="verifyResult.ok ? 'fas fa-check-circle' : 'fas fa-times-circle'"></i>
        {{ verifyResult.detail }}
      </p>
      <p class="tray-tip">
        <i class="fas fa-info-circle"></i>
        获取方法（须用自己设备）：运行仓库内置 tools/szlm-generator 一键生成器（自动在本地模拟器注册真实数字联盟ID，Windows/macOS/Linux 均可）；或手机抓包官方酷安的 X-App-Device 头，逆序 Base64 解码后取首字段；或 adb logcat 过滤 szlm/ddid。填写后点"验证"确认可用——验证需先登录，会临时套用该 ID 探测写接口并自动恢复原身份，无副作用。
      </p>
      <p class="szlm-warning">
        <i class="fas fa-exclamation-triangle"></i>
        必须填写自己手机的数字联盟ID：共享或使用他人的ID会被风控封禁，设备号被封后该手机将无法使用酷安。填写后建议在"自定义设备指纹"中将机型设为与该手机一致，以降低校验风险。
      </p>
    </div>

    <div class="setting-group">
      <h4 class="group-title">随机设备码</h4>
      <div class="setting-row">
        <div class="row-info">
          <span class="row-label">随时随机生成</span>
          <span class="row-sub">立即掷出新的随机设备码并生效（设备码被风控时可换新身份），无需重启客户端</span>
        </div>
        <div class="szlm-actions">
          <button
            v-if="deviceInfo?.codeSource === 'random'"
            class="action-button compact"
            @click="resetDeviceCode"
          >
            <i class="fas fa-undo"></i>
            恢复默认
          </button>
          <button
            class="action-button compact primary"
            :disabled="deviceInfo?.szlmActive"
            :title="deviceInfo?.szlmActive ? '数字联盟ID生效中，请先清空后再随机生成' : ''"
            @click="randomizeDeviceCode"
          >
            <i class="fas fa-random"></i>
            随机生成
          </button>
        </div>
      </div>
      <p class="tray-tip">
        <i class="fas fa-info-circle"></i>
        随机设备码只更换客户端的伪装身份，随时生成、随时恢复默认（账号绑定/游客）；数字联盟ID填写的真实身份优先级更高，与随机设备码互斥。
      </p>
    </div>

    <div class="setting-group">
      <h4 class="group-title">自定义设备指纹</h4>
      <div class="setting-row">
        <div class="row-info">
          <span class="row-label">启用自定义设备信息</span>
          <span class="row-sub">自定义请求头中的机型、版本与系统信息（关闭后使用客户端默认值）</span>
        </div>
        <AppSwitch v-model="settingsStore.settings.deviceFingerprint.customFingerprint" />
      </div>
    </div>

    <template v-if="settingsStore.settings.deviceFingerprint.customFingerprint">
      <div class="setting-group">
        <h4 class="group-title">机型模板</h4>
        <div class="setting-row">
          <div class="row-info">
            <span class="row-label">预设机型</span>
            <span class="row-sub">一键套用常见机型模板，或选择"自定义"手动输入</span>
          </div>
          <div class="preset-actions">
            <select v-model="presetModel" class="text-input select-input">
              <option value="">自定义机型</option>
              <option v-for="p in DEVICE_PRESETS" :key="p.model" :value="p.model">
                {{ p.label }}（{{ p.model }}）
              </option>
            </select>
            <button class="mini-button" title="随机套用一款机型" @click="randomizePreset">
              <i class="fas fa-random"></i>
            </button>
          </div>
        </div>

        <div class="setting-row">
          <div class="row-info">
            <span class="row-label">机型型号</span>
            <span class="row-sub">内嵌于 User-Agent，如 23113RKC6C（小米 14）</span>
          </div>
          <input
            v-model="settingsStore.settings.deviceFingerprint.model"
            type="text"
            class="text-input"
            placeholder="如：23113RKC6C"
            maxlength="40"
          />
        </div>

        <div class="field-row">
          <div class="row-info">
            <span class="row-label">Android 版本</span>
            <span class="row-sub">UA 中的 Android 版本号</span>
          </div>
          <input
            v-model="settingsStore.settings.deviceFingerprint.androidVersion"
            type="text"
            class="text-input small-input"
            placeholder="16"
            maxlength="8"
          />
          <div class="row-info">
            <span class="row-label">Build 号</span>
            <span class="row-sub">UA 中的 Build 版本</span>
          </div>
          <input
            v-model="settingsStore.settings.deviceFingerprint.build"
            type="text"
            class="text-input"
            placeholder="AQ3A.250226.002"
            maxlength="40"
          />
        </div>
      </div>

      <div class="setting-group">
        <h4 class="group-title">应用与系统信息</h4>
        <div class="field-row">
          <div class="row-info">
            <span class="row-label">App 版本（X-App-Version）</span>
            <span class="row-sub">不得低于酷安官方最低支持版本</span>
          </div>
          <input
            v-model="settingsStore.settings.deviceFingerprint.appVersion"
            type="text"
            class="text-input small-input"
            placeholder="16.2.0"
            maxlength="20"
          />
          <div class="row-info">
            <span class="row-label">版本号（X-App-Code）</span>
            <span class="row-sub">同步作用于 X-App-Supported</span>
          </div>
          <input
            v-model="settingsStore.settings.deviceFingerprint.appCode"
            type="text"
            class="text-input small-input"
            placeholder="2604201"
            maxlength="12"
          />
        </div>

        <div class="field-row">
          <div class="row-info">
            <span class="row-label">SDK Int（X-Sdk-Int）</span>
            <span class="row-sub">Android SDK 版本号</span>
          </div>
          <input
            v-model="settingsStore.settings.deviceFingerprint.sdkInt"
            type="text"
            class="text-input small-input"
            placeholder="35"
            maxlength="4"
          />
          <div class="row-info">
            <span class="row-label">语言（X-Sdk-Locale）</span>
            <span class="row-sub">如 zh-CN / en-US</span>
          </div>
          <input
            v-model="settingsStore.settings.deviceFingerprint.locale"
            type="text"
            class="text-input small-input"
            placeholder="zh-CN"
            maxlength="16"
          />
        </div>

        <div class="setting-row">
          <div class="row-info">
            <span class="row-label">暗色模式（X-Dark-Mode）</span>
            <span class="row-sub">模拟客户端深浅色状态，与界面主题相互独立</span>
          </div>
          <AppSwitch
            :model-value="settingsStore.settings.deviceFingerprint.darkMode === '1'"
            @update:model-value="(v: boolean) => (settingsStore.settings.deviceFingerprint.darkMode = v ? '1' : '0')"
          />
        </div>
      </div>

      <div class="setting-group">
        <h4 class="group-title">预览</h4>
        <div class="preview-box">
          <div class="preview-row">
            <span class="preview-key">User-Agent</span>
            <code class="preview-value">{{ previewUserAgent }}</code>
          </div>
          <div class="preview-row">
            <span class="preview-key">X-App-Version</span>
            <code class="preview-value">{{ fingerprint.appVersion || '16.2.0' }}</code>
            <span class="preview-key">X-App-Code</span>
            <code class="preview-value">{{ fingerprint.appCode || '2604201' }}</code>
          </div>
          <div class="preview-row">
            <span class="preview-key">X-Sdk-Int</span>
            <code class="preview-value">{{ fingerprint.sdkInt || '35' }}</code>
            <span class="preview-key">X-Sdk-Locale</span>
            <code class="preview-value">{{ fingerprint.locale || 'zh-CN' }}</code>
            <span class="preview-key">X-Dark-Mode</span>
            <code class="preview-value">{{ fingerprint.darkMode }}</code>
          </div>
          <p v-if="versionWarning" class="version-warning">
            <i class="fas fa-exclamation-triangle"></i>
            {{ versionWarning }}
          </p>
        </div>
      </div>

      <div class="setting-group">
        <button class="reset-button" @click="resetToDefault">
          <i class="fas fa-undo"></i>
          恢复默认设置
        </button>
      </div>
    </template>

    <div class="setting-group">
      <h4 class="group-title">注意事项</h4>
      <p class="tray-tip">
        <i class="fas fa-info-circle"></i>
        除数字联盟ID外，设备码（X-App-Device）与请求令牌（X-App-Token）绑定账号，不支持自定义。修改机型、版本等字段后，若酷安返回"网络环境异常"或"请升级客户端"，说明该组合被服务端拒绝，请恢复默认或改用其他机型模板。
      </p>
      <p class="tray-tip">
        <i class="fas fa-info-circle"></i>
        修改立即生效，无需重启客户端，作用于所有请求（含发布动态、评论、点赞等）。
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useSettingsStore, buildDeviceUserAgent } from '../../stores/settings';
import AppSwitch from '../../components/common/AppSwitch.vue';
import { DEVICE_PRESETS } from '../../utils/devicePresets';
import { invoke } from '@tauri-apps/api/core';
import { useAuthStore } from '../../stores/auth';
import { showToast } from '../../utils/toast';
import type { DeviceFingerprintSettings } from '../../types/settings';

/** 当前生效设备信息（Rust 端查询）：登录态 + 数字联盟ID覆盖态 + 设备码来源 + 设备码 */
const deviceInfo = ref<{
  loggedIn: boolean;
  deviceCode: string;
  szlmActive?: boolean;
  codeSource?: 'szlm' | 'random' | 'account' | 'guest';
} | null>(null);

const authStore = useAuthStore();

async function loadDeviceInfo() {
  try {
    const res = await invoke<any>('get_device_info');
    if (res && res.code === 200) {
      deviceInfo.value = res.data;
    }
  } catch (err) {
    console.warn('获取设备信息失败:', err);
  }
}
onMounted(loadDeviceInfo);
// 登录/登出/切换账号后刷新设备码状态
watch(
  () => authStore.user?.uid,
  () => loadDeviceInfo()
);

const settingsStore = useSettingsStore();

const fingerprint = computed(() => settingsStore.settings.deviceFingerprint);
const previewUserAgent = computed(() => buildDeviceUserAgent(fingerprint.value));

const CODE_SOURCE_LABELS: Record<string, string> = {
  szlm: '数字联盟ID',
  random: '随机生成',
  account: '账号绑定',
  guest: '游客（本机固定）',
};
const codeSourceLabel = computed(
  () => CODE_SOURCE_LABELS[deviceInfo.value?.codeSource ?? ''] ?? '加载中...'
);

/** 数字联盟ID可用性验证：临时套用该 ID 探测写接口（Rust 端自动恢复原身份） */
const verifying = ref(false);
const verifyResult = ref<{ ok: boolean; detail: string } | null>(null);
async function verifySzlm() {
  const id = fingerprint.value.szlmId.trim();
  if (!id || verifying.value) return;
  verifying.value = true;
  verifyResult.value = null;
  try {
    const res = await invoke<any>('verify_szlm_id', { szlmId: id });
    if (res?.code === 200 && res.data) {
      verifyResult.value = { ok: !!res.data.ok, detail: res.data.detail || '验证完成' };
    } else {
      verifyResult.value = { ok: false, detail: '验证接口无响应' };
    }
  } catch (err) {
    verifyResult.value = { ok: false, detail: `验证失败：${err}` };
  } finally {
    verifying.value = false;
  }
}

/** 随机重掷设备码（风控换新身份），随时可再掷或恢复默认 */
async function randomizeDeviceCode() {
  try {
    await invoke('regenerate_device_code');
    showToast('已生成新的随机设备码', 'success');
  } catch (err) {
    showToast(String(err), 'error');
  }
  loadDeviceInfo();
}

/** 清除随机覆盖，恢复默认设备码（数字联盟ID > 账号绑定 > 游客） */
async function resetDeviceCode() {
  try {
    await invoke('reset_device_code');
    showToast('已恢复默认设备码', 'success');
  } catch (err) {
    showToast(String(err), 'error');
  }
  loadDeviceInfo();
}

/** 随机套用一款机型模板（避开当前机型），SDK 版本随安卓版本联动 */
const ANDROID_SDK_MAP: Record<string, string> = { '14': '34', '15': '35', '16': '36' };
function randomizePreset() {
  const current = fingerprint.value.model.trim();
  const pool = DEVICE_PRESETS.filter((p) => p.model !== current);
  const preset = pool[Math.floor(Math.random() * pool.length)];
  if (!preset) return;
  Object.assign(fingerprint.value, {
    model: preset.model,
    androidVersion: preset.androidVersion,
    build: preset.build,
    sdkInt: ANDROID_SDK_MAP[preset.androidVersion] ?? fingerprint.value.sdkInt,
  });
}

// 数字联盟ID 变更后延迟刷新设备码显示（Rust 端已即时生效）
let szlmRefreshTimer: ReturnType<typeof setTimeout> | undefined;
watch(
  () => fingerprint.value.szlmId,
  () => {
    clearTimeout(szlmRefreshTimer);
    szlmRefreshTimer = setTimeout(loadDeviceInfo, 400);
  }
);

const presetModel = computed({
  get: () => {
    const f = fingerprint.value;
    return DEVICE_PRESETS.some((p) => p.model === f.model.trim()) ? f.model.trim() : '';
  },
  set: (model: string) => {
    const preset = DEVICE_PRESETS.find((item) => item.model === model);
    if (!preset) return;
    Object.assign(fingerprint.value, {
      model: preset.model,
      androidVersion: preset.androidVersion,
      build: preset.build,
    });
  },
});

const versionWarning = computed(() => {
  const f = fingerprint.value;
  const code = Number(f.appCode);
  if (!Number.isNaN(code) && code > 0 && code < 2604201) {
    return `版本号 ${f.appCode} 低于当前官方版本 2604201，服务端可能拒绝请求（err_request_need_upgrade_new_version）。`;
  }
  const version = f.appVersion.trim();
  if (version) {
    const major = Number(version.split('.')[0]);
    if (!Number.isNaN(major) && major > 0 && major < 16) {
      return `App 版本 ${version} 低于当前官方主版本 16，服务端可能拒绝请求。`;
    }
  }
  return '';
});

function resetToDefault() {
  const defaults: DeviceFingerprintSettings = {
    customFingerprint: true,
    model: '23113RKC6C',
    androidVersion: '16',
    build: 'AQ3A.250226.002',
    appVersion: '16.2.0',
    appCode: '2604201',
    sdkInt: '35',
    locale: 'zh-CN',
    darkMode: '0',
    szlmId: '',
  };
  Object.assign(settingsStore.settings.deviceFingerprint, defaults);
}
</script>

<style scoped>
.settings-section {
  display: flex;
  flex-direction: column;
  gap: var(--space-6);
  max-width: 760px;
}

.section-title {
  font-size: var(--font-size-title-md);
  font-weight: var(--font-weight-bold);
  color: var(--text-primary);
  border-bottom: 1px solid var(--border);
  padding-bottom: var(--space-3);
}

.setting-group {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.group-title {
  font-size: var(--font-size-title-sm);
  font-weight: var(--font-weight-semibold);
  color: var(--text-primary);
}

.setting-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-4);
  padding: var(--space-3) 0;
  border-bottom: 1px solid var(--border-light);
}

.field-row {
  display: flex;
  align-items: center;
  gap: var(--space-4);
  padding: var(--space-3) 0;
  border-bottom: 1px solid var(--border-light);
}

.row-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  flex: 1;
  min-width: 120px;
}

.row-label {
  font-size: var(--font-size-sub);
  font-weight: var(--font-weight-medium);
  color: var(--text-primary);
}

.row-sub {
  font-size: var(--font-size-caption);
  color: var(--text-tertiary);
}

.text-input {
  background-color: var(--background);
  border: 1px solid var(--border);
  border-radius: var(--radius-control);
  padding: 6px 12px;
  font-size: var(--font-size-sub);
  color: var(--text-primary);
  outline: none;
  width: 220px;
  transition: border-color var(--duration-fast) var(--ease-default);
}

.small-input {
  width: 130px;
}

.szlm-input {
  width: 280px;
  font-family: var(--font-mono, Consolas, monospace);
}

.szlm-actions {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}

.preset-actions {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}

.mini-button {
  width: 32px;
  height: 32px;
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background-color: var(--background);
  border: 1px solid var(--border);
  border-radius: var(--radius-control);
  font-size: var(--font-size-sub);
  color: var(--text-secondary);
  cursor: pointer;
  transition: all var(--duration-fast) var(--ease-default);
}

.mini-button:hover {
  border-color: var(--brand-primary);
  color: var(--brand-primary);
}

.action-button {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  background-color: var(--background);
  border: 1px solid var(--border);
  border-radius: var(--radius-control);
  padding: 8px 16px;
  font-size: var(--font-size-sub);
  color: var(--text-secondary);
  cursor: pointer;
  white-space: nowrap;
  transition: all var(--duration-fast) var(--ease-default);
}

.action-button.compact {
  padding: 6px 14px;
}

.action-button:hover:not(:disabled) {
  border-color: var(--brand-primary);
  color: var(--brand-primary);
}

.action-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.action-button.primary {
  color: var(--brand-primary);
}

.verify-result {
  font-size: var(--font-size-caption);
  display: flex;
  gap: var(--space-2);
  align-items: flex-start;
  margin: 0;
}

.verify-result i {
  margin-top: 2px;
}

.verify-result.ok {
  color: var(--brand-primary);
}

.verify-result.fail {
  color: #e0533d;
}

.select-input {
  width: 230px;
  cursor: pointer;
}

.text-input:hover,
.text-input:focus {
  border-color: var(--brand-primary);
}

.preview-box {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  background-color: var(--background);
  border: 1px solid var(--border);
  border-radius: var(--radius-card);
  padding: var(--space-4);
}

.preview-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  flex-wrap: wrap;
}

.preview-key {
  font-size: var(--font-size-caption);
  color: var(--text-tertiary);
  white-space: nowrap;
}

.preview-value {
  font-family: var(--font-mono, Consolas, monospace);
  font-size: var(--font-size-caption);
  color: var(--text-primary);
  background-color: var(--surface);
  border-radius: var(--radius-control);
  padding: 2px 8px;
  word-break: break-all;
}

.version-warning {
  font-size: var(--font-size-caption);
  color: #e0533d;
  margin: var(--space-2) 0 0;
}

.szlm-warning {
  font-size: var(--font-size-caption);
  color: #e0533d;
  display: flex;
  gap: var(--space-2);
  align-items: flex-start;
  margin: 0;
}

.szlm-warning i {
  margin-top: 2px;
}

.status-box {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  background-color: var(--background);
  border: 1px solid var(--border);
  border-radius: var(--radius-card);
  padding: var(--space-4);
}

.status-row {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.status-key {
  font-size: var(--font-size-caption);
  color: var(--text-tertiary);
  white-space: nowrap;
  width: 130px;
}

.status-value {
  font-size: var(--font-size-sub);
  font-weight: var(--font-weight-medium);
}

.status-on {
  color: var(--brand-primary);
}

.status-off {
  color: #e0533d;
}

.status-code {
  font-family: var(--font-mono, Consolas, monospace);
  font-size: var(--font-size-caption);
  color: var(--text-primary);
  background-color: var(--surface);
  border-radius: var(--radius-control);
  padding: 2px 8px;
  word-break: break-all;
  max-width: 420px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.reset-button {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  align-self: flex-start;
  background-color: var(--background);
  border: 1px solid var(--border);
  border-radius: var(--radius-control);
  padding: 8px 16px;
  font-size: var(--font-size-sub);
  color: var(--text-secondary);
  cursor: pointer;
  transition: all var(--duration-fast) var(--ease-default);
}

.reset-button:hover {
  border-color: var(--brand-primary);
  color: var(--brand-primary);
}

.tray-tip {
  font-size: var(--font-size-caption);
  color: var(--text-tertiary);
  display: flex;
  gap: var(--space-2);
  align-items: flex-start;
  margin: 0;
}

.tray-tip i {
  margin-top: 2px;
}
</style>
