import { useEffect, useState } from 'react';
import { Download } from 'lucide-react';
import {
  canDownloadOfflineAudio,
  downloadOfflineAudio,
  getOfflineAudioProgress,
  offlineAudioCount,
} from '../utils/offlineAudio';

export function OfflineAudioSettings() {
  const [completed, setCompleted] = useState(0);
  const [downloading, setDownloading] = useState(false);
  const [failed, setFailed] = useState(false);
  const supported = canDownloadOfflineAudio();
  const [controlled, setControlled] = useState(() => Boolean(navigator.serviceWorker?.controller));

  useEffect(() => {
    if (!supported) return;
    const update = () => setControlled(Boolean(navigator.serviceWorker.controller));
    update();
    navigator.serviceWorker.addEventListener('controllerchange', update);
    return () => navigator.serviceWorker.removeEventListener('controllerchange', update);
  }, [supported]);

  useEffect(() => {
    if (!supported) return;
    let active = true;
    void getOfflineAudioProgress().then((count) => {
      if (active) setCompleted(count);
    }).catch(() => {
      if (active) setFailed(true);
    });
    return () => { active = false; };
  }, [supported]);

  async function download() {
    setDownloading(true);
    setFailed(false);
    try {
      await downloadOfflineAudio(setCompleted);
    } catch {
      setFailed(true);
    } finally {
      setDownloading(false);
    }
  }

  const ready = completed === offlineAudioCount;

  return (
    <section className="settings-card">
      <div className="settings-card-header">
        <div className="settings-card-title">
          <Download size={16} />
          <h3>离线发音</h3>
        </div>
      </div>
      <p className="settings-desc">
        基础发音包包含字母名称、有内置录音的常用词和全部场景短句。
      </p>
      {supported && controlled ? (
        <>
          <span className="muted-caption" role="status">
            {failed ? '下载未完成，可重试并继续下载剩余录音。' :
              ready ? '已下载，可离线播放。' : `已下载 ${completed} / ${offlineAudioCount} 段`}
          </span>
          {!ready && (
            <div>
              <button type="button" className="btn-primary btn-sm" disabled={downloading} onClick={download}>
                {downloading ? '正在下载…' : failed ? '重试下载' : '下载基础发音包'}
              </button>
            </div>
          )}
        </>
      ) : (
        <p className="settings-desc">
          {supported ? '离线服务就绪后即可下载发音包。' : '当前浏览器无法保存离线发音包。'}
        </p>
      )}
    </section>
  );
}
