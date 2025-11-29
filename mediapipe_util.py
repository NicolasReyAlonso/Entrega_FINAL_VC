import asyncio
import json
import cv2
import mediapipe as mp
import websockets

# 17 puntos: cabeza + torso + brazos + piernas
KEYPOINTS = [0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]

# Conexiones del esqueleto
POSE_CONNECTIONS = [
    (11, 13), (13, 15),   # brazo izquierdo
    (12, 14), (14, 16),   # brazo derecho
    (11, 12),             # hombros
    (23, 24),             # caderas
    (11, 23), (12, 24),   # torso
    (23, 25), (25, 27),   # pierna izquierda
    (24, 26), (26, 28)    # pierna derecha
]

connected_clients = set()

async def stream_pose(websocket):
    """Maneja la conexión de un cliente WebSocket"""
    connected_clients.add(websocket)
    print(f"Cliente conectado. Total: {len(connected_clients)}")
    
    try:
        await websocket.wait_closed()
    finally:
        connected_clients.remove(websocket)
        print(f"Cliente desconectado. Total: {len(connected_clients)}")

async def capture_and_broadcast():
    """Captura poses y las transmite a todos los clientes"""
    cap = cv2.VideoCapture(0)
    
    BaseOptions = mp.tasks.BaseOptions
    PoseLandmarker = mp.tasks.vision.PoseLandmarker
    PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
    VisionRunningMode = mp.tasks.vision.RunningMode
    
    options = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path="pose_landmarker_full.task"),
        num_poses=2,  # Detectar hasta 2 personas
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
            poses_data = []
            
            if result.pose_landmarks:
                h, w, _ = debug_frame.shape
                
                # Colores para diferentes jugadores
                colors = [(0, 255, 0), (255, 0, 255)]  # Verde y Magenta
                
                for idx, landmarks in enumerate(result.pose_landmarks[:2]):
                    color = colors[idx]
                    
                    # Dibujar puntos
                    for lm in landmarks:
                        cx = int(lm.x * w)
                        cy = int(lm.y * h)
                        cv2.circle(debug_frame, (cx, cy), 6, color, -1)
                    
                    # Dibujar conexiones
                    for a, b in POSE_CONNECTIONS:
                        if a < len(landmarks) and b < len(landmarks):
                            ax = int(landmarks[a].x * w)
                            ay = int(landmarks[a].y * h)
                            bx = int(landmarks[b].x * w)
                            by = int(landmarks[b].y * h)
                            cv2.line(debug_frame, (ax, ay), (bx, by), color, 2)
                    
                    # Extraer puntos clave
                    pose_points = [
                        {"x": landmarks[i].x, "y": landmarks[i].y} 
                        for i in KEYPOINTS
                    ]
                    poses_data.append(pose_points)
            
            # Enviar datos a todos los clientes conectados
            if connected_clients:
                message = json.dumps({"poses": poses_data})
                disconnected = set()
                
                for client in connected_clients:
                    try:
                        await client.send(message)
                    except:
                        disconnected.add(client)
                
                # Limpiar clientes desconectados
                connected_clients.difference_update(disconnected)
            
            cv2.imshow("MediaPipe Pose Debug (Multijugador)", debug_frame)
            if cv2.waitKey(1) & 0xFF == 27:
                break
            
            await asyncio.sleep(0.01)
    
    finally:
        cap.release()
        cv2.destroyAllWindows()

async def main():
    print("Servidor WebSocket activo en ws://localhost:8765")
    print("Detectando hasta 2 jugadores...")
    
    # Iniciar servidor WebSocket y captura en paralelo
    server = await websockets.serve(stream_pose, "localhost", 8765)
    capture_task = asyncio.create_task(capture_and_broadcast())
    
    await asyncio.gather(capture_task, asyncio.Future())

if __name__ == "__main__":
    asyncio.run(main())