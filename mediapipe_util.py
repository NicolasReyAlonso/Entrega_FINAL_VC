
import asyncio
import json
import cv2
import mediapipe as mp
import websockets

# 11 puntos (incluye cabeza 0)
KEYPOINTS = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26]

# Conexiones del esqueleto (para dibujado en debug)
POSE_CONNECTIONS = [
    (11, 13), (13, 15),   # brazo izquierdo
    (12, 14), (14, 16),   # brazo derecho
    (11, 12),             # hombros
    (23, 24),             # caderas
    (11, 23), (12, 24)    # torso
]

async def stream_pose(websocket):
    cap = cv2.VideoCapture(0)

    BaseOptions = mp.tasks.BaseOptions
    PoseLandmarker = mp.tasks.vision.PoseLandmarker
    PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
    VisionRunningMode = mp.tasks.vision.RunningMode

    options = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path="pose_landmarker_full.task"),
        num_poses=1,
        running_mode=VisionRunningMode.VIDEO
    )

    detector = PoseLandmarker.create_from_options(options)
    time_ms = 0

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                await asyncio.sleep(0.01)
                continue

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

            result = detector.detect_for_video(mp_image, time_ms)
            time_ms += 33

            debug_frame = frame.copy()

            if result.pose_landmarks:
                landmarks = result.pose_landmarks[0]  # 33 landmarks (NormalizedLandmark)

                h, w, _ = debug_frame.shape

                # ---- DIBUJAR PUNTOS ----
                for lm in landmarks:
                    cx = int(lm.x * w)
                    cy = int(lm.y * h)
                    cv2.circle(debug_frame, (cx, cy), 6, (0, 255, 0), -1)

                # ---- DIBUJAR CONEXIONES ----
                for a, b in POSE_CONNECTIONS:
                    if a < len(landmarks) and b < len(landmarks):
                        ax = int(landmarks[a].x * w)
                        ay = int(landmarks[a].y * h)
                        bx = int(landmarks[b].x * w)
                        by = int(landmarks[b].y * h)
                        cv2.line(debug_frame, (ax, ay), (bx, by), (0, 255, 0), 2)

                # ---- Enviar a Godot los 11 puntos ----
                out = [{"x": landmarks[i].x, "y": landmarks[i].y} for i in KEYPOINTS]
                await websocket.send(json.dumps(out))

            cv2.imshow("MediaPipe Pose Debug", debug_frame)
            if cv2.waitKey(1) & 0xFF == 27:
                break
    finally:
        cap.release()
        cv2.destroyAllWindows()

async def main():
    print("Servidor WebSocket activo en ws://localhost:8765")
    async with websockets.serve(stream_pose, "localhost", 8765):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
