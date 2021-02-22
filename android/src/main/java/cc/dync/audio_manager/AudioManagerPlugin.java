package cc.dync.audio_manager;

import android.content.Context;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * AudioManagerPlugin
 */
public class AudioManagerPlugin implements FlutterPlugin, MethodCallHandler{

    private static AudioManagerPlugin instance;
    private Context context;
    private MethodChannel channel;
    private MediaPlayerHelper helper;

    private static FlutterAssets flutterAssets;
    private static Registrar registrar;

    private static synchronized AudioManagerPlugin getInstance()
    {
        if (instance == null)
        {
            instance = new AudioManagerPlugin();
        }
        return instance;
    }

    public AudioManagerPlugin()
    {
        if (instance == null)
        {
            instance = this;
        }
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        final MethodChannel channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "audio_manager");

        channel.setMethodCallHandler(getInstance());
        setup(flutterPluginBinding.getApplicationContext(), channel);
        AudioManagerPlugin.flutterAssets = flutterPluginBinding.getFlutterAssets();
    }

    // This static function is optional and equivalent to onAttachedToEngine. It
    // supports the old
    // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
    // plugin registration via this function while apps migrate to use the new
    // Android APIs
    // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
    //
    // It is encouraged to share logic between onAttachedToEngine and registerWith
    // to keep
    // them functionally equivalent. Only one of onAttachedToEngine or registerWith
    // will be called
    // depending on the user's project. onAttachedToEngine or registerWith must both
    // be defined
    // in the same class.
    public static void registerWith(Registrar registrar) {
        MethodChannel channel = new MethodChannel(registrar.messenger(), "audio_manager");

        channel.setMethodCallHandler(getInstance());
        instance.setup(registrar.context(), channel);
        AudioManagerPlugin.registrar = registrar;
    }

    private void setup(Context context, MethodChannel channel) {
        instance.context = context;
        instance.channel = channel;

        instance.helper = MediaPlayerHelper.getInstance(instance.context);
        setupPlayer();
    }

    private void setupPlayer()
    {
        MediaPlayerHelper helper = instance.helper;
        MethodChannel channel = instance.channel;

        helper.setOnStatusCallbackListener((status, args) -> {
            Log.v(TAG, "--" + status.toString());
            switch (status) {
                case ready:
                    channel.invokeMethod("ready", null);
                    break;
                case error:
                    Log.v(TAG, "Error:" + args[0]);
                    channel.invokeMethod("error", args[0]);
                    helper.stop();
                    break;
                case ended:
                    channel.invokeMethod("ended", null);
                    break;
                case stop:
                    channel.invokeMethod("stop", null);
                    break;
            }
        });
    }

    private static final String TAG = "AudioManagerPlugin";

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        MediaPlayerHelper helper = instance.helper;
        switch (call.method)
        {
            case "getPlatformVersion":
                result.success("Android " + android.os.Build.VERSION.RELEASE);
                break;
            case "start":
                String url = call.argument("url");
                if (registrar != null)
                {
                    url = registrar.lookupKeyForAsset(url);
                }
                else if (flutterAssets != null)
                {
                    url = AudioManagerPlugin.flutterAssets.getAssetFilePathByName(url);
                }
                try
                {
                    helper.start(url);
                }
                catch (Exception e)
                {
                    result.success(e.getMessage());
                }
                break;
            case "play":
                helper.play();
                break;
            case "stop":
                helper.stop();
            case "release":
                helper.release();
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding)
    {
    }
}
