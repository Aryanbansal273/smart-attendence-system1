package io.flutter.plugins.localauth;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;

public class LocalAuthPlugin implements FlutterPlugin, ActivityAware {
    @Override
    public void onAttachedToEngine(FlutterPlugin.FlutterPluginBinding binding) {
        // Dummy implementation
    }

    @Override
    public void onDetachedFromEngine(FlutterPlugin.FlutterPluginBinding binding) {
        // Dummy implementation
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