package cc.dync.audio_manager;

import android.content.Context;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.media.MediaPlayer;
import android.os.PowerManager;
import android.util.Log;

public class MediaPlayerHelper {
    private static final String TAG = MediaPlayerHelper.class.getSimpleName();

    private final Holder uiHolder;
    private final Context context;
    private static MediaPlayerHelper instance;
    
    public enum CallBackState
    {
        stop("stop"),
        ended("Ended"),
        error("Error"),
        INFO("播放开始"),
        ready("准备完毕");

        private final String state;

        CallBackState(String state)
        {
            this.state = state;
        }

        public String toString()
        {
            return this.state;
        }
    }
    
    public static synchronized MediaPlayerHelper getInstance(Context context)
    {
        if (instance == null)
        {
            instance = new MediaPlayerHelper(context);
        }
        return instance;
    }
    
    void start(String url) throws Exception
    {
        if (url == null) throw new Exception("you must invoke setInfo method before");

        stop();
        uiHolder.player = new MediaPlayer();
        initPlayerListener();
    
        beginPlayAsset(url);
    }
    
    void play()
    {
        uiHolder.player.start();
    }
    
    public void stop()
    {
        if (uiHolder.player != null)
        {
            uiHolder.player.release();
            uiHolder.player = null;
        }
        onStatusCallbackNext(CallBackState.stop);
    }

    /**
     * 释放资源
     */
    public void release()
    {
        stop();
    }
    
    private MediaPlayerHelper(Context context)
    {
        if (instance == null)
        {
            instance = this;
        }
        this.context = context;
        this.uiHolder = new Holder();
    }

    /**
     * 时间监听
     */
    private void initPlayerListener()
    {
        uiHolder.player.setOnCompletionListener(mp -> {
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
        uiHolder.player.setOnPreparedListener(mp ->
        {
            try
            {
                uiHolder.player.start();
                onStatusCallbackNext(CallBackState.ready, "Ready");
            }
            catch(Exception e)
            {
                Log.d(TAG, "initPlayerListener: "+e.getMessage());
            }
        });
    }

    private void beginPlayAsset(String assetName)
    {
        AssetManager assetMg = context.getAssets();
        try
        {
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
    
    private static final class Holder
    {
        private MediaPlayer player;
        private AssetFileDescriptor assetDescriptor;
    }


    private OnStatusCallbackListener onStatusCallbackListener;

    public interface OnStatusCallbackListener
    {
        void onStatusOnStatusCallbackNext(CallBackState status, Object... args);
    }

    public void setOnStatusCallbackListener(OnStatusCallbackListener onStatusCallbackListener)
    {
        this.onStatusCallbackListener = onStatusCallbackListener;
    }

    private void onStatusCallbackNext(CallBackState status, Object... args)
    {
        if (onStatusCallbackListener != null)
        {
            onStatusCallbackListener.onStatusOnStatusCallbackNext(status, args);
        }
    }
}
