# 🖨️ CUPS Print Server - Enhanced Version 1.1.0

## 🚀 Nieuwe Features & Verbeteringen

### ✅ **Configureerbare Instellingen**
De add-on is nu volledig configureerbaar via de Home Assistant UI - geen hardcoded wachtwoorden meer!

### 🛡️ **Robuustheid & Stabiliteit**
- **Auto-restart** bij crashes
- **Health checks** om service status te monitoren  
- **Betere error handling** met retry mechanisms
- **Graceful shutdown** met proper cleanup

### ⚙️ **Eenvoudige Configuratie**
Alle instellingen zijn nu aanpasbaar via de add-on configuratie:

```yaml
cups_username: "jouw-gebruikersnaam"    # Standaard: "print"
cups_password: "jouw-wachtwoord"       # Standaard: "print"  
server_name: "Jouw Print Server"       # Standaard: "CUPS Print Server"
log_level: "info"                      # debug, info, warn, error
max_jobs: 100                         # Maximum aantal print jobs
enable_web_interface: true            # Web interface aan/uit
ssl_enabled: true                     # HTTPS versleuteling  
restart_on_failure: true             # Auto-restart bij crashes
```

## 📋 **Configuratie Instructies**

### **Stap 1: Add-on Installeren**
1. Voeg de repository toe in Home Assistant
2. Installeer de "CUPS Print Server" add-on
3. **Start de add-on NIET direct!**

### **Stap 2: Configuratie Aanpassen**
Ga naar de add-on configuratie en pas de instellingen aan naar jouw wensen:

#### **Basis Instellingen:**
- **Username**: Verander `print` naar jouw gewenste gebruikersnaam
- **Password**: Gebruik een sterk wachtwoord (niet "print"!)
- **Server Name**: Geef je print server een herkenbare naam

#### **Geavanceerde Instellingen:**
- **Log Level**: `debug` voor troubleshooting, `info` voor normaal gebruik
- **Max Jobs**: Verhoog naar 200+ voor drukke omgevingen
- **Web Interface**: Schakel uit voor extra beveiliging
- **SSL**: Hou aan voor veilige verbindingen
- **Auto Restart**: Hou aan voor maximale uptime

### **Stap 3: Add-on Starten**
Na het configureren kun je de add-on veilig starten.

## 🔧 **Troubleshooting**

### **Add-on start niet?**
1. Check de logs: `Home Assistant → Add-ons → CUPS Print Server → Log`
2. Controleer configuratie: ongeldige waardes kunnen opstarten voorkomen
3. Probeer met standaard configuratie eerst

### **Kan niet inloggen?**
- Controleer username/password in add-on configuratie
- Web interface bereikbaar via: `https://homeassistant.local:631`
- Gebruik de ingestelde credentials, niet "print/print"

### **Printers niet gevonden?**
1. Controleer of USB devices correct doorverbonden zijn
2. Check Avahi service in logs
3. Herstart add-on als Avahi niet start

### **Crashes nog steeds?**
1. Zet `log_level` op `debug` 
2. Controleer `restart_on_failure` = `true`
3. Check system resources (geheugen/CPU)
4. Bekijk de volledige logs voor error details

## 📊 **Monitoring & Health Checks**

De add-on bevat nu ingebouwde health checks:
- **CUPS daemon status**
- **HTTPS response check** 
- **Avahi service check**
- **Automatic restarts** bij failures

## 🔒 **Beveiliging**

### **Standaard Beveiliging:**
- **HTTPS-only** communicatie (TLS 1.3)
- **Geen HTTP** toegang meer
- **Configureerbare credentials**
- **Encryption required** voor alle operaties

### **Aanbevelingen:**
1. Verander altijd de standaard credentials
2. Gebruik sterke wachtwoorden  
3. Schakel web interface uit indien niet nodig
4. Monitor logs regelmatig

## 🆕 **Migratie van Oude Versie**

Als je upgrade van v1.0.0:
1. **Stop de oude add-on**
2. **Backup je printer configuratie** (indien belangrijk)
3. **Update naar v1.1.0**
4. **Configureer nieuwe instellingen**
5. **Start add-on** - configuratie wordt automatisch gemigreerd

## 📝 **Changelog v1.1.0**

### **Toegevoegd:**
- ✅ Configureerbare username/password
- ✅ Dynamische server configuratie
- ✅ Robuuste error handling
- ✅ Auto-restart functionaliteit  
- ✅ Health monitoring
- ✅ Betere logging opties
- ✅ Graceful shutdown
- ✅ SSL certificate management

### **Verbeterd:**
- 🔧 Startup sequence optimalisatie
- 🔧 Service dependency handling  
- 🔧 Memory/CPU efficiency
- 🔧 Configuration validation
- 🔧 Documentation & user guidance

### **Opgelost:**
- 🐛 Random crashes door race conditions
- 🐛 Hardcoded credentials probleem
- 🐛 Service startup failures
- 🐛 SSL certificate issues
- 🐛 Poor error recovery
