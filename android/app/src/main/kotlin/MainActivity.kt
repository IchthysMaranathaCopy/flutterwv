import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WebViewPlatform.instance.registerWith(
            flutterEngine.dartExecutor.binaryMessenger,
            WebViewFactory(this, flutterEngine.dartExecutor)
        )
    }
}
