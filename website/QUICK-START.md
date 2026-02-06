# 🎯 TOME Website - Quick Start

## 📁 What Was Created

```
website/
├── index.html (13KB)         - Main website with all content
├── styles.css (15KB)         - Glassmorphic design + animations
├── script.js (11KB)          - GSAP scroll animations
├── preview.sh (1KB)          - Local preview helper script
├── README.md (9KB)           - Complete documentation
├── DEPLOY.md (6KB)           - Deployment guide
├── Tome V3 v1.fbx (741KB)    - 3D model (for future use)
└── assets/
    ├── images/               - Product photos, logos
    ├── screenshots/          - Software UI screenshots
    └── renders/              - 3D hardware renders
```

## 🚀 Two Commands to Get Started

### 1. Preview Locally
```bash
cd /Users/matthewreichard/git/macos-focus-utility/website
./preview.sh
```
Opens http://localhost:8000 in your browser automatically.

### 2. Deploy to Internet (Free)
```bash
npx vercel
```
Follow prompts → Your site is live in 60 seconds!

---

## 🎨 Design Features

✨ **Apple/Nothing-inspired minimalism**
- Pure black background (#000000)
- Glassmorphic effects with subtle borders
- Smooth GSAP scroll animations
- Responsive for all devices
- Helvetica Neue typography

🌈 **Environment-specific colors**
- Writer's Desk: Green (#00ff88)
- Workshop: Purple (#9d00ff)
- Coffeeshop: Orange (#ff8800)
- Garden: Green (#00ff44)

---

## 🌐 Free Hosting Options

| Platform | URL | Deploy Command |
|----------|-----|----------------|
| **Vercel** ⭐ | `tome.vercel.app` | `npx vercel` |
| **Netlify** | `tome.netlify.app` | Drag & drop |
| **GitHub Pages** | `username.github.io/tome` | Git push |
| **Cloudflare** | `tome.pages.dev` | `wrangler pages publish .` |

**All include:**
- ✅ Free HTTPS
- ✅ Global CDN
- ✅ Custom domain support
- ✅ Automatic deployments

---

## 🆓 Free Domain Options

### Instant (No registration)
- `tome.vercel.app` - Via Vercel
- `tome.netlify.app` - Via Netlify
- `tome.pages.dev` - Via Cloudflare

### Free TLDs (Freenom)
- `tome.tk` - Tokelau
- `tome.ml` - Mali
- `tome.ga` - Gabon
- `tome.cf` - Central African Republic

**Get at:** [freenom.com](https://www.freenom.com)

### Developer Domain
- `tome.is-a.dev` - Clean, professional
- **Get at:** [github.com/is-a-dev/register](https://github.com/is-a-dev/register)

---

## 📱 Sections Included

1. **Hero** - Focus revolution headline + hardware image
2. **Physical Meets Digital** - Feature cards + phone ritual
3. **Four Worlds of Work** - Writer's Desk, Workshop, Coffeeshop, Garden
4. **Intelligence** - Smart notifications, task estimation, AI features
5. **Experience** - Full workspace showcase
6. **Footer** - Links and branding

---

## 🛠️ Customization

### Change colors:
Edit `styles.css` line 15-22 (CSS variables)

### Update images:
Replace files in `assets/` folders

### Modify content:
Edit `index.html` (semantic HTML sections)

---

## 📞 Commands Cheatsheet

```bash
# Preview
./preview.sh                    # Auto-opens browser
python3 -m http.server 8000     # Manual start

# Deploy
npx vercel                      # Vercel (fastest)
netlify deploy --prod           # Netlify
git push                        # GitHub Pages (after setup)

# Stop local server
Ctrl + C                        # In terminal
pkill -f "http.server"          # Force kill
```

---

## ✅ Pre-Launch Checklist

Before deploying:
- [ ] Test locally with `./preview.sh`
- [ ] Check all images load
- [ ] Test on mobile (Chrome DevTools)
- [ ] Verify animations work smoothly
- [ ] Review content for typos
- [ ] Test navigation links

After deploying:
- [ ] Test live URL
- [ ] Check HTTPS is enabled
- [ ] Test on real mobile device
- [ ] Verify on multiple browsers
- [ ] Share with team for feedback

---

## 🎓 Libraries Used

- **GSAP 3** - Smooth animations
- **ScrollTrigger** - Scroll-based effects
- **Three.js** - Ready for 3D (not yet implemented)

All loaded via CDN (no installation needed).

---

## 🚨 Common Issues

**Images not showing?**
→ Run a local server (don't just open index.html)

**Animations not working?**
→ Check browser console, verify CDN links

**Custom domain not working?**
→ Wait 24-48 hours for DNS propagation

**Port 8000 in use?**
→ `pkill -f "http.server"` then retry

---

## 📚 Full Documentation

- **README.md** - Complete guide with all options
- **DEPLOY.md** - Detailed deployment instructions
- This file - Quick reference

---

## 🎯 Recommended Workflow

```bash
# 1. Test locally
cd /Users/matthewreichard/git/macos-focus-utility/website
./preview.sh

# 2. Make changes (edit HTML/CSS/JS)

# 3. Refresh browser to see changes

# 4. When ready, deploy
npx vercel

# 5. (Optional) Add custom domain
# Follow instructions in DEPLOY.md

# Done! 🎉
```

---

**Time to deploy:** ~5 minutes
**Cost:** $0 (completely free)
**Maintenance:** None needed

**Built with ❤️ for TOME - The Focus Revolution**
