## Tecnologías:
- Capturar video en tiempo real → opencv-python
- Detectar postura / contorno del jugador → MediaPipe (pose o holistic).
- Envío de poses al motor → WebSockets
- Motor de videojuegos → godot
- Modelador → blender
- DAW → LMMS
- Entorno de dibujo → Krita

## **INSTRUCCIONES DE INSTALACIÓN**
### ENTORNO
```bash
conda create --name VC_FINAL python=3.11.14
conda activate VC_FINAL
pip install websockets mediapipe opencv-python
```
- Importar el proyecto [Brain Wall](./BrainWallGodot/brain-wall/project.godot) a godot
### **LANZAMIENTO DEL JUEGO**
1. Correr el script de python [mediapipe_util.py](./mediapipe_util.py) y dejarlo corriendo
2. Correr el proyecto godot dandole al boton play.