
package com.intivoto.flutter_geofence;

import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.FlutterShellArgs;

import java.util.Collections;
import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.CountDownLatch;

public class FlutterGeofenceBackgroundService extends JobIntentService {
    private static final String TAG = "FGeofenceService";

    private static final List<Intent> messagingQueue =
            Collections.synchronizedList(new LinkedList<>());

    /**
     * Background Dart execution context.
     */
    private static FlutterGeofenceBackgroundExecutor flutterBackgroundExecutor;

    /**
     * Schedule the message to be handled by the {@link FlutterGeofenceBackgroundService}.
     */
    public static void enqueueMessageProcessing(Context context, Intent messageIntent) {
        enqueueWork(
                context,
                FlutterGeofenceBackgroundService.class,
                FlutterGeofenceUtils.JOB_ID,
                messageIntent,
                true);
    }

    /**
     * Starts the background isolate for the {@link FlutterGeofenceBackgroundService}.
     *
     * <p>Preconditions:
     *
     * <ul>
     *   <li>The given {@code callbackHandle} must correspond to a registered Dart callback. If the
     *       handle does not resolve to a Dart callback then this method does nothing.
     *   <li>A static {@link #pluginRegistrantCallback} must exist, otherwise a {@link
     *       PluginRegistrantException} will be thrown.
     * </ul>
     */
    @SuppressWarnings("JavadocReference")
    public static void startBackgroundIsolate(long callbackHandle, FlutterShellArgs shellArgs) {
        if (flutterBackgroundExecutor != null) {
            Log.w(TAG, "Attempted to start a duplicate background isolate. Returning...");
            return;
        }
        flutterBackgroundExecutor = new FlutterGeofenceBackgroundExecutor();
        flutterBackgroundExecutor.startBackgroundIsolate(callbackHandle, shellArgs);
    }

    static void onInitialized() {
        Log.i(TAG, "FlutterGeofenceBackgroundService started!");
//        synchronized (messagingQueue) {
//            // Handle all the message events received before the Dart isolate was
//            // initialized, then clear the queue.
//            for (Intent intent : messagingQueue) {
//                flutterBackgroundExecutor.executeDartCallbackInBackgroundIsolate(intent, null);
//            }
//            messagingQueue.clear();
//        }
    }

    /**
     * Sets the Dart callback handle for the Dart method that is responsible for initializing the
     * background Dart isolate, preparing it to receive Dart callback tasks requests.
     */
    public static void setCallbackDispatcher(long callbackHandle) {
        FlutterGeofenceBackgroundExecutor.setCallbackDispatcher(callbackHandle);
    }

    /**
     * Sets the Dart callback handle for the users Dart handler that is responsible for handling
     * messaging events in the background.
     */
    public static void setUserCallbackHandle(long callbackHandle) {
        FlutterGeofenceBackgroundExecutor.setUserCallbackHandle(callbackHandle);
    }

    @Override
    public void onCreate() {
        super.onCreate();
        if (flutterBackgroundExecutor == null) {
            flutterBackgroundExecutor = new FlutterGeofenceBackgroundExecutor();
        }
        flutterBackgroundExecutor.startBackgroundIsolate();
    }


    @Override
    protected void onHandleWork(@NonNull final Intent intent) {
        if (!flutterBackgroundExecutor.isDartBackgroundHandlerRegistered()) {
            Log.w(
                    TAG,
                    "A background message could not be handled in Dart as no onBackgroundGeofenceEvent handler has been registered.");
            return;
        }

        // If we're in the middle of processing queued messages, add the incoming
        // intent to the queue and return.
//        synchronized (messagingQueue) {
//            if (flutterBackgroundExecutor.isNotRunning()) {
//                Log.i(TAG, "Service has not yet started, messages will be queued.");
//                messagingQueue.add(intent);
//                return;
//            }
//        }

        // There were no pre-existing callback requests. Execute the callback
        // specified by the incoming intent.
        final CountDownLatch latch = new CountDownLatch(1);
        new Handler(getMainLooper())
                .post(
                        () -> flutterBackgroundExecutor.executeDartCallbackInBackgroundIsolate(intent, latch));

        try {
            latch.await();
        } catch (InterruptedException ex) {
            Log.i(TAG, "Exception waiting to execute Dart callback", ex);
        }
    }
}
