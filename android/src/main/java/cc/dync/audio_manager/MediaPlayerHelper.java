package cc.dync.audio_manager;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.Message;
import android.os.PowerManager;
import android.util.Log;

public class MediaPlayerHelper {
    private static final String TAG = MediaPlayerHelper.class.getSimpleName();

    private String[] ext = {".3gp", ".3GP", ".mp4", ".MP4", ".mp3", ".ogg", ".OGG", ".MP3", ".wav", ".WAV"};//定义我们支持的文件格式
    private Holder uiHolder;//UI的容器
    private Context context;
    private MediaInfo mediaInfo = new MediaInfo("title", null);
    private static MediaPlayerHelper instance;
    private int delaySecondTime = 1000;//进度回调间隔
    private boolean isHolderCreate = false;//SurfaceHolder是否准备好了
    private String curUrl = "";//当前初始化url
    private boolean isPrepare = false;

    static class MediaInfo {
        String title;
        /**
         * 资源路径
         * if isAsset: true （url 名字,带后缀，比如:text.mp3
         * else url is file path or network path
         */
        String url;
        /**
         * 资源描述
         */
        String desc;
        /**
         * 封面图地址
         */
        String cover;
        /**
         * 是否是通过Assets文件名播放Assets目录下的音频
         */
        boolean isAsset = false;
       
        boolean isAuto = true;

        MediaInfo(String title, String url) {
            this.title = title;
            this.url = url;
        }
    }

    /**
     * 状态枚举
     */
    public enum CallBackState {
        buffering("MediaPlayer--更新流媒体缓存状态"),
        next("next"),
        previous("previous"),
        playOrPause("playOrPause"),
        stop("stop"),
        ended("播放结束"),
        error("播放错误"),
        INFO("播放开始"),
        ready("准备完毕"),
        progress("播放进度回调"),
        seekComplete("拖动完成");

        private final String state;

        CallBackState(String state) {
            this.state = state;
        }

        public String toString() {
            return this.state;
        }
    }

    /**
     * 获得静态类
     *
     * @param context 引用
     * @return 实例
     */
    public static synchronized MediaPlayerHelper getInstance(Context context)
    {
        if (instance == null)
        {
            instance = new MediaPlayerHelper(context);
        }
        return instance;
    }
    
    void start(MediaInfo info) throws Exception
    {
        if (info.url.equals(curUrl)) {
            play();
            return;
        }
        this.mediaInfo = info;
        if (mediaInfo.url == null) throw new Exception("you must invoke setInfo method before");

        stop();
        uiHolder.player = new MediaPlayer();
        keepAlive();
        initPlayerListener();
    
        beginPlayAsset(mediaInfo.url);

        curUrl = mediaInfo.url;
        isPrepare = false;
    }
    
    void play()
    {
        Log.d(TAG, "play: "+canPlay());
        Log.d(TAG, "play: "+isPlaying());
        if (canPlay()) return;
        if (isPlaying()) return;
        uiHolder.player.start();
        onStatusCallbackNext(CallBackState.playOrPause, isPlaying());
    }

    void pause() {
        if (canPlay()) return;
        if (!isPlaying()) return;
        uiHolder.player.pause();
        onStatusCallbackNext(CallBackState.playOrPause, isPlaying());
    }

    void playOrPause() {
        if (canPlay()) return;
        if (isPlaying()) {
            uiHolder.player.pause();
        } else {
            uiHolder.player.start();
        }
        onStatusCallbackNext(CallBackState.playOrPause, isPlaying());
    }

    private boolean canPlay()
    {
        if (!isPrepare) {
            Log.e(TAG, "媒体资源加载失败");
            onStatusCallbackNext(CallBackState.error, "媒体资源加载失败");
        }
        return isPrepare;
    }

    boolean isPlaying() {
        if (uiHolder.player == null) return false;
        return uiHolder.player.isPlaying();
    }

    int position() {
        if (uiHolder.player == null) return 0;
        return uiHolder.player.getCurrentPosition();
    }

    int duration() {
        if (uiHolder.player == null) return 0;
        return uiHolder.player.getDuration();
    }
    
    public void stop() {
        if (uiHolder.player != null) {
            uiHolder.player.release();
            uiHolder.player = null;
        }
        onStatusCallbackNext(CallBackState.stop);
        refress_time_handler.removeCallbacks(refress_time_Thread);

        curUrl = "";
        isPrepare = false;
    }
    
    public void release() {
        stop();
    }
    
    private MediaPlayerHelper(Context context) {
        if (instance == null) {
            instance = this;
        }
        this.context = context;
        this.uiHolder = new Holder();
    }
    
    private void initPlayerListener() {
        uiHolder.player.setOnCompletionListener(mp -> {
            onStatusCallbackNext(CallBackState.progress, 100);
            onStatusCallbackNext(CallBackState.ended, mp);
        });
        uiHolder.player.setOnErrorListener((mp, what, extra) -> {
            String errorString = "what:" + what + " extra:" + extra;
            onStatusCallbackNext(CallBackState.error, errorString);
            return false;
        });
        uiHolder.player.setOnInfoListener((mp, what, extra) -> {
            onStatusCallbackNext(CallBackState.INFO, mp, what, extra);
            return false;
        });
    }
    
    private void beginPlayAsset(String assetName)
    {
        AssetManager assetMg = context.getAssets();
        try {
            uiHolder.assetDescriptor = assetMg.openFd(assetName);
            uiHolder.player.setDisplay(null);
            uiHolder.player.reset();
            uiHolder.player.setDataSource(uiHolder.assetDescriptor.getFileDescriptor(), uiHolder.assetDescriptor.getStartOffset(), uiHolder.assetDescriptor.getLength());
            uiHolder.player.prepareAsync();
        }
        catch (Exception e)
        {
            onStatusCallbackNext(CallBackState.error, e.toString());
        }
    }

    private void keepAlive()
    {
        uiHolder.player.setWakeMode(context, PowerManager.PARTIAL_WAKE_LOCK);
    }
    
    private final Handler refress_time_handler = new Handler(){
        @Override
        public void handleMessage(Message msg) {
            switch (msg.what){
                case ERROR:
                    onStatusCallbackNext(CallBackState.error, msg.obj);
                    break;
            }
        }
    };
    private final Runnable refress_time_Thread = new Runnable() {
        public void run() {
            refress_time_handler.removeCallbacks(refress_time_Thread);
            try {
                if (uiHolder.player != null && uiHolder.player.isPlaying()) {
                    int duraction = uiHolder.player.getDuration();
                    if (duraction > 0) {
                        onStatusCallbackNext(CallBackState.progress, 100 * uiHolder.player.getCurrentPosition() / duraction);
                    }
                }
            } catch (IllegalStateException e) {
                onStatusCallbackNext(CallBackState.error, e.toString());
            }
            refress_time_handler.postDelayed(refress_time_Thread, delaySecondTime);
        }
    };

    private static final int ERROR = 0x1;

    /* ***************************** Holder封装UI ***************************** */

    private static final class Holder {
        private MediaPlayer player;
        private AssetFileDescriptor assetDescriptor;
    }

    /* ***************************** StatusCallback ***************************** */

    private OnStatusCallbackListener onStatusCallbackListener;

    public interface OnStatusCallbackListener {
        void onStatusonStatusCallbackNext(CallBackState status, Object... args);
    }

    public MediaPlayerHelper setOnStatusCallbackListener(OnStatusCallbackListener onStatusCallbackListener) {
        this.onStatusCallbackListener = onStatusCallbackListener;
        return instance;
    }

    private void onStatusCallbackNext(CallBackState status, Object... args) {
        if(onStatusCallbackListener != null) {
            onStatusCallbackListener.onStatusonStatusCallbackNext(status, args);
        }
    }
}
