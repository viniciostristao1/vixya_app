# Vixya — app Android (Flutter) — LER PRIMEIRO

App cliente do **Vixya** (gerador automático de vídeos de marketing). É **magro**: só grava/seleciona
material, manda para o backend na VPS, mostra o preview e compartilha. **Todo o trabalho pesado
(IA, FFmpeg, render) é no backend** (`/root/vixya`, serviço na VPS). Ver [[project-vixya-video-maker]].

- **Flutter** (mesmo padrão dos outros apps do usuário). Projeto em `app/`. Build de APK **na nuvem**
  (`.github/workflows/build-apk.yml`) — Flutter NÃO fica na VPS.
- **Sem Firebase** (diferente dos outros apps): o Vixya fala só com o backend na VPS.

## Fluxo do usuário
1. Escolhe um **vídeo** (gravação de tela) + **prints**.
2. Escreve uma **frase de objetivo**, escolhe **estilo** e **modelo de IA** (lista vem do backend).
3. Toca **GERAR** → o app manda tudo pro backend.
4. Backend: OCR + cortes → IA cria o roteiro → renderiza **preview**.
5. App mostra o preview → botões **Outra versão** / **Aprovar**.
6. Aprovado → render final → **Salvar / Compartilhar** (Sharesheet).

## ⚠️ Pré-requisito para funcionar
O backend hoje roda em `127.0.0.1:8090` na VPS (localhost). Para o celular alcançar, é preciso
**expor o backend com segurança** (HTTPS + token). Enquanto isso não existe, configure a **URL do
backend + token** em *Configurações* dentro do app (tela de settings). Ver `LANCAMENTO`/backend.

## Telas (`app/lib/`)
- `config.dart` — URL do backend + token (salvos no aparelho).
- `api.dart` — cliente HTTP do backend (jobs, preview, versão, aprovar, vídeo, modelos).
- `screens/new_video_screen.dart` — seleção + GERAR.
- `screens/progress_screen.dart` — status, preview, outra versão/aprovar, compartilhar.
- `screens/settings_screen.dart` — URL + token do backend.

## Build (na nuvem, como os outros apps)
Push na `main` (mudanças em `app/**`) → CI gera o scaffold Android + compila o APK (release,
assinado com chave de debug para teste) → baixa o APK no artifact do workflow.
