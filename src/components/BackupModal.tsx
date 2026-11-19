import React, { useRef, useState } from 'react';
import { Check, Copy, Download, Upload, X } from 'lucide-react';
import { applyBackup, BackupPreview, parseBackup, readRestorePoint } from '../utils/backup';

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
  const [preview, setPreview] = useState<BackupPreview | null>(null);
  const readRequest = useRef(0);

  if (!isOpen) return null;
  const restorePoint = readRestorePoint();

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

  function prepareBackup(raw: string) {
    setStatusMsg(null);
    setPreview(null);
    try {
      setPreview(parseBackup(raw));
    } catch (error) {
      setStatusMsg(error instanceof Error ? error.message : '无法读取备份。');
    }
  }

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    e.target.value = '';
    const request = ++readRequest.current;
    setPreview(null);
    setStatusMsg(null);
    try {
      const raw = await file.text();
      if (request === readRequest.current) prepareBackup(raw);
    } catch {
      if (request === readRequest.current) setStatusMsg('无法读取此备份文件。');
    }
  }

  function confirmRestore() {
    if (!preview || preview.labels.length === 0) return;
    try {
      applyBackup(preview);
      window.location.reload();
    } catch {
      setStatusMsg('无法写入备份，请检查设备存储空间后重试。');
    }
  }

  function close() {
    readRequest.current++;
    setPreview(null);
    setStatusMsg(null);
    onClose();
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
          <button type="button" className="win-btn" onClick={close} title="关闭">
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
            onChange={(e) => {
              readRequest.current++;
              setPreview(null);
              setPasteText(e.target.value);
            }}
            placeholder="或直接粘贴从另一台设备复制的 JSON 备份文本..."
          />
          {pasteText.trim() && (
            <button
              type="button"
              className="btn-primary btn-sm"
              onClick={() => {
                readRequest.current++;
                prepareBackup(pasteText);
              }}
            >
              预览粘贴的备份
            </button>
          )}
        </div>

        {restorePoint && restorePoint.labels.length > 0 && (
          <div className="modal-actions-row">
            <button type="button" className="btn-secondary btn-sm" onClick={() => {
              readRequest.current++;
              setStatusMsg(null);
              setPreview(restorePoint);
            }}>
              预览上次恢复前的状态
            </button>
          </div>
        )}

        {preview && (
          <section className="modal-section" aria-label="恢复预览">
            <h4>{preview.restorePoint ? '撤销上次恢复' : '恢复预览'}</h4>
            <p className="muted-caption">
              {preview.labels.length
                ? `将更改 ${preview.labels.length} 项：${preview.labels.join('、')}。`
                : '备份内容与当前数据相同。'}
            </p>
            {preview.ignored > 0 && <p className="muted-caption">已忽略 {preview.ignored} 项无法识别的数据。</p>}
            {preview.labels.length > 0 && <p className="muted-caption">确认后会在本机保存当前状态，便于撤销。</p>}
            <div className="modal-actions-row">
              <button type="button" className="btn-secondary btn-sm" onClick={() => setPreview(null)}>取消预览</button>
              <button type="button" className="btn-primary btn-sm" disabled={!preview.labels.length} onClick={confirmRestore}>
                {preview.restorePoint ? '确认撤销' : '确认恢复'}
              </button>
            </div>
          </section>
        )}

        {statusMsg && <p className="backup-status-msg" role="status">{statusMsg}</p>}
      </div>
    </div>
  );
};
