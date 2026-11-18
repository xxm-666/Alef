import React, { useState } from 'react';
import { Check, Copy, Download, Upload, X } from 'lucide-react';

interface BackupModalProps {
  isOpen: boolean;
  onClose: () => void;
  lettersMastered: number;
  wordsMastered: number;
  srsCount: number;
}

const BACKUP_PREFIX = 'alef.';

export const BackupModal: React.FC<BackupModalProps> = ({
  isOpen,
  onClose,
  lettersMastered,
  wordsMastered,
  srsCount,
}) => {
  const [pasteText, setPasteText] = useState('');
  const [statusMsg, setStatusMsg] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  function buildBackupPayload(): string {
    const data: Record<string, unknown> = {};
    for (let i = 0; i < localStorage.length; i += 1) {
      const key = localStorage.key(i);
      if (key && key.startsWith(BACKUP_PREFIX)) {
        try {
          data[key] = JSON.parse(localStorage.getItem(key) ?? 'null');
        } catch {
          data[key] = localStorage.getItem(key);
        }
      }
    }
    return JSON.stringify(
      {
        app: 'Alef',
        version: 1,
        exportedAt: new Date().toISOString(),
        data,
      },
      null,
      2
    );
  }

  function handleDownloadJson() {
    const json = buildBackupPayload();
    const blob = new Blob([json], { type: 'application/json;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `alef-backup-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
    setStatusMsg('已下载 JSON 备份文件。');
  }

  async function handleCopyJson() {
    try {
      await navigator.clipboard.writeText(buildBackupPayload());
      setCopied(true);
      setStatusMsg('已复制备份数据到剪贴板，可在另一台设备粘贴恢复。');
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      setStatusMsg('剪贴板复制失败，请使用「下载备份文件」。');
    }
  }

  function applyBackupJson(raw: string) {
    try {
      const parsed = JSON.parse(raw) as { app?: string; data?: Record<string, unknown> };
      if (!parsed || typeof parsed !== 'object' || !parsed.data || typeof parsed.data !== 'object') {
        setStatusMsg('格式无效：请确保导入的是 Alef 导出的 JSON 备份。');
        return;
      }
      let restoredCount = 0;
      for (const [key, val] of Object.entries(parsed.data)) {
        if (key.startsWith(BACKUP_PREFIX)) {
          localStorage.setItem(key, JSON.stringify(val));
          restoredCount += 1;
        }
      }
      setStatusMsg(`成功恢复 ${restoredCount} 项配置与进度，正在刷新页面...`);
      window.setTimeout(() => {
        window.location.reload();
      }, 800);
    } catch {
      setStatusMsg('JSON 解析失败，请检查内容是否完整。');
    }
  }

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') {
        applyBackupJson(reader.result);
      }
    };
    reader.readAsText(file);
  }

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label="学习进度备份与同步">
      <div className="modal-card">
        <div className="modal-header">
          <div>
            <h3>学习进度备份与跨设备同步</h3>
            <p className="muted-caption">
              已掌握字母 {lettersMastered} · 已掌握单词 {wordsMastered} · 复习计划 {srsCount} 项
            </p>
          </div>
          <button type="button" className="win-btn" onClick={onClose} title="关闭">
            <X size={16} />
          </button>
        </div>

        <div className="modal-section">
          <h4>导出当前进度</h4>
          <div className="modal-actions-row">
            <button type="button" className="btn-primary btn-sm" onClick={handleDownloadJson}>
              <Download size={14} />
              <span>下载 JSON 备份</span>
            </button>
            <button type="button" className="btn-secondary btn-sm" onClick={handleCopyJson}>
              {copied ? <Check size={14} /> : <Copy size={14} />}
              <span>{copied ? '已复制' : '复制备份文本'}</span>
            </button>
          </div>
        </div>

        <div className="modal-section">
          <h4>从备份恢复（会覆盖当前设备进度）</h4>
          <label className="btn-secondary btn-sm file-upload-btn">
            <Upload size={14} />
            <span>选择 JSON 备份文件</span>
            <input type="file" accept="application/json,.json" onChange={handleFileChange} hidden />
          </label>
          <textarea
            className="backup-textarea"
            rows={4}
            value={pasteText}
            onChange={(e) => setPasteText(e.target.value)}
            placeholder="或直接粘贴从另一台设备复制的 JSON 备份文本..."
          />
          {pasteText.trim() && (
            <button
              type="button"
              className="btn-primary btn-sm"
              onClick={() => applyBackupJson(pasteText)}
            >
              确认恢复粘贴的备份
            </button>
          )}
        </div>

        {statusMsg && <p className="backup-status-msg">{statusMsg}</p>}
      </div>
    </div>
  );
};
