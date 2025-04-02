package io.flutter.plugins.urllauncher;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class UrlLauncherPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(FlutterPlugin.FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "plugins.flutter.io/url_launcher");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPlugin.FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        // Dummy implementation
        result.notImplemented();
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        // Dummy implementation
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        // Dummy implementation
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        // Dummy implementation
    }

    @Override
    public void onDetachedFromActivity() {
        // Dummy implementation
    }
}