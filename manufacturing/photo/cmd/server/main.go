package main

import (
    "fmt"
    "html/template"
    "log"
    "net/http"
    "os"
)

var (
    version       = getEnv("APP_VERSION", "dev")
    image         = getEnv("APP_IMAGE", "unknown")
    textColor     = getEnv("TEXT_COLOR", "#FFFFFF")
    bgColor       = getEnv("BG_COLOR", "#2C3E50")
    port          = getEnv("PORT", "8080")
)

const htmlTemplate = `



    
    
    K8s Demo Service
    
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: {{.BgColor}};
            color: {{.TextColor}};
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            text-align: center;
            max-width: 800px;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 2rem;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .info-card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 2rem;
            margin: 1rem 0;
            box-shadow: 0 8px 32px rgba(0,0,0,0.2);
        }
        .info-label {
            font-size: 1rem;
            opacity: 0.8;
            margin-bottom: 0.5rem;
            text-transform: uppercase;
            letter-spacing: 2px;
        }
        .info-value {
            font-size: 1.5rem;
            font-weight: bold;
            word-break: break-all;
        }
        .hostname {
            margin-top: 2rem;
            padding-top: 2rem;
            border-top: 1px solid rgba(255,255,255,0.2);
            opacity: 0.7;
        }
        @media (max-width: 600px) {
            h1 {
                font-size: 2rem;
            }
            .info-value {
                font-size: 1.2rem;
            }
        }
    


    
        🚀 K8s Demo Service
        
        
            Container Image
            {{.Image}}
        
        
        
            Version
            {{.Version}}
        
        
        
            Hostname
            {{.Hostname}}
        
    


`

type PageData struct {
    Version   string
    Image     string
    TextColor string
    BgColor   string
    Hostname  string
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func handleRoot(w http.ResponseWriter, r *http.Request) {
    hostname, err := os.Hostname()
    if err != nil {
        hostname = "unknown"
    }

    data := PageData{
        Version:   version,
        Image:     image,
        TextColor: textColor,
        BgColor:   bgColor,
        Hostname:  hostname,
    }

    tmpl, err := template.New("index").Parse(htmlTemplate)
    if err != nil {
        http.Error(w, "Template error", http.StatusInternalServerError)
        log.Printf("Template parsing error: %v", err)
        return
    }

    w.Header().Set("Content-Type", "text/html; charset=utf-8")
    if err := tmpl.Execute(w, data); err != nil {
        log.Printf("Template execution error: %v", err)
    }
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    fmt.Fprintf(w, `{"status":"healthy","version":"%s"}`, version)
}

func main() {
    http.HandleFunc("/", handleRoot)
    http.HandleFunc("/health", handleHealth)
    http.HandleFunc("/healthz", handleHealth)
    http.HandleFunc("/ready", handleHealth)

    addr := ":" + port
    log.Printf("Starting server on %s", addr)
    log.Printf("Version: %s", version)
    log.Printf("Image: %s", image)
    log.Printf("Text Color: %s", textColor)
    log.Printf("Background Color: %s", bgColor)

    if err := http.ListenAndServe(addr, nil); err != nil {
        log.Fatal(err)
    }
}