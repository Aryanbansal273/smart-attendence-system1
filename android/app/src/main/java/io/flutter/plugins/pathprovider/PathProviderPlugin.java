package io.flutter.plugins.pathprovider;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class PathProviderPlugin implements FlutterPlugin, MethodCallHandler {
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(FlutterPlugin.FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "plugins.flutter.io/path_provider");
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
}