# 🚀 TOME Website - Deployment Guide

## Quick Start (Fastest Way)

### 1. Preview Locally

```bash
# Navigate to website folder
cd /Users/matthewreichard/git/macos-focus-utility/website

# Run preview script
./preview.sh

# Or manually:
python3 -m http.server 8000
# Then open: http://localhost:8000
```

### 2. Deploy to Vercel (Recommended - 5 minutes)

```bash
# Option A: One-click deploy (no installation needed)
npx vercel

# Follow prompts:
# ? Set up and deploy? Y
# ? Which scope? (your account)
# ? Link to existing project? N
# ? What's your project's name? tome-website
# ? In which directory is your code located? ./
# ? Override settings? N

# ✅ Done! Your site is live at: https://tome-website.vercel.app
```

**Add custom domain (Optional):**
1. Go to [vercel.com/dashboard](https://vercel.com/dashboard)
2. Select your project → Settings → Domains
3. Add domain: `tome.tk` (or any Freenom domain)
4. Follow DNS instructions

---

## Free Domain Options

### Option 1: Freenom (.tk, .ml, .ga, .cf, .gq)

**Get a free domain:**

1. Go to [freenom.com](https://www.freenom.com)
2. Search for your desired domain (e.g., "tome")
3. Select a free extension: `.tk`, `.ml`, `.ga`, `.cf`, or `.gq`
4. Click "Get it now" → Complete the order (FREE for 12 months)
5. Register/login with email

**Setup with Vercel:**
1. In Vercel dashboard, go to: Project → Settings → Domains
2. Add your domain: `tome.tk`
3. Copy the DNS records shown
4. Go to Freenom → My Domains → Manage Domain → Management Tools → Nameservers
5. Choose "Use custom nameservers"
6. Add Vercel's nameservers:
   - `ns1.vercel-dns.com`
   - `ns2.vercel-dns.com`
7. Save and wait 24-48 hours for DNS propagation

### Option 2: is-a.dev (Developer subdomain)

**Get a clean developer domain:**

1. Go to [is-a-dev GitHub](https://github.com/is-a-dev/register)
2. Fork the repository
3. Create a file: `domains/tome.json`
   ```json
   {
     "description": "TOME - Focus Revolution",
     "repo": "https://github.com/YOUR_USERNAME/tome-website",
     "owner": {
       "username": "YOUR_USERNAME",
       "email": "your@email.com"
     },
     "record": {
       "CNAME": "tome-website.vercel.app"
     }
   }
   ```
4. Create Pull Request
5. Wait for approval (usually within 24 hours)
6. You get: `tome.is-a.dev` (FREE forever!)

---

## Detailed Platform Guides

### Vercel (Best for Performance)

**Why:** Fastest CDN, instant deployments, zero config

```bash
# Install Vercel CLI (one time)
npm install -g vercel

# Deploy
cd /Users/matthewreichard/git/macos-focus-utility/website
vercel

# For production deployment
vercel --prod

# Your site: https://tome-website.vercel.app
```

**Custom Domain:**
- Dashboard → Project → Settings → Domains
- Add domain and follow DNS instructions
- Automatic HTTPS included

---

### Netlify (Great UI)

**Why:** Easy drag-and-drop, great dashboard

**Method 1: Drag & Drop**
1. Go to [netlify.com](https://netlify.com)
2. Sign up (free)
3. Drag the `website` folder onto dashboard
4. Done! Site is live at: `random-name.netlify.app`

**Method 2: CLI**
```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy
cd /Users/matthewreichard/git/macos-focus-utility/website
netlify deploy --prod

# Your site: https://tome-website.netlify.app
```

**Custom Domain:**
- Dashboard → Domain settings → Add custom domain
- Follow DNS instructions

---

### GitHub Pages (Free Forever)

**Why:** Unlimited free hosting, git integration

```bash
# 1. Create GitHub repo
cd /Users/matthewreichard/git/macos-focus-utility/website
git init
git add .
git commit -m "Initial TOME website"

# 2. Push to GitHub
# Create repo at github.com/new named: tome-website
git remote add origin https://github.com/YOUR_USERNAME/tome-website.git
git branch -M main
git push -u origin main

# 3. Enable GitHub Pages
# Go to: Settings → Pages → Source: main branch → Save

# Your site: https://YOUR_USERNAME.github.io/tome-website
```

**Custom Domain:**
1. Create file `CNAME` in repo with your domain:
   ```
   tome.tk
   ```
2. At Freenom, add A records:
   ```
   185.199.108.153
   185.199.109.153
   185.199.110.153
   185.199.111.153
   ```

---

### Cloudflare Pages (Ultra Fast)

**Why:** Best global CDN, unlimited bandwidth

```bash
# 1. Install Wrangler CLI
npm install -g wrangler

# 2. Login
wrangler login

# 3. Deploy
cd /Users/matthewreichard/git/macos-focus-utility/website
wrangler pages publish .

# Your site: https://tome-website.pages.dev
```

---

## Quick Comparison

| Platform | Speed | Free Domain | Ease | Custom Domain |
|----------|-------|-------------|------|---------------|
| **Vercel** | ⚡⚡⚡⚡⚡ | .vercel.app | 🟢 Easy | ✅ Free |
| **Netlify** | ⚡⚡⚡⚡ | .netlify.app | 🟢 Easiest | ✅ Free |
| **GitHub Pages** | ⚡⚡⚡ | .github.io | 🟡 Medium | ✅ Free |
| **Cloudflare** | ⚡⚡⚡⚡⚡ | .pages.dev | 🟡 Medium | ✅ Free |

**Recommendation:** Start with **Vercel** - one command deploy, fastest performance.

---

## Post-Deployment Checklist

- [ ] Test website on mobile devices
- [ ] Check all images load correctly
- [ ] Test navigation links
- [ ] Verify animations work smoothly
- [ ] Test on multiple browsers
- [ ] Check custom domain (if using)
- [ ] Enable HTTPS (automatic on all platforms)
- [ ] Add analytics if needed

---

## Updating Your Site

### Vercel
```bash
# Make changes to your files, then:
vercel --prod
```

### Netlify
```bash
netlify deploy --prod
```

### GitHub Pages
```bash
git add .
git commit -m "Update website"
git push
# Auto-deploys in ~1 minute
```

---

## Troubleshooting

### "Command not found: vercel/netlify"
```bash
npm install -g vercel
# or
npm install -g netlify-cli
```

### "Images not showing"
- Check file paths are correct
- Ensure images are in `assets/` folder
- Clear browser cache

### "Animations not working"
- Check browser console for errors
- Verify CDN links are loading (check Network tab)

### "Custom domain not working"
- Wait 24-48 hours for DNS propagation
- Clear DNS cache: `sudo dscacheutil -flushcache`
- Try incognito mode
- Verify DNS records are correct

---

## Need Help?

1. Check the main [README.md](README.md)
2. Test locally first: `./preview.sh`
3. Check browser console for errors
4. Try deploying to Vercel (simplest option)

---

**🎯 Recommended Flow:**

```bash
# 1. Preview locally
./preview.sh

# 2. Deploy to Vercel
npx vercel

# 3. (Optional) Add custom domain from Freenom
# Follow instructions above

# Done! 🎉
```
