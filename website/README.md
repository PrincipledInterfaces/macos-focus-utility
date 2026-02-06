# TOME Website

A beautiful, minimalistic marketing website for TOME - inspired by Apple and Nothing's design language.

## ✨ Features

- **Glassmorphic Design**: Subtle glass-effect cards with backdrop blur
- **Smooth Animations**: GSAP-powered scroll animations and transitions
- **Responsive Layout**: Fully optimized for desktop, tablet, and mobile
- **Performance Optimized**: Lazy loading, reduced motion support, GPU acceleration
- **Accessibility**: Keyboard navigation, screen reader friendly, reduced motion support

## 🚀 Local Preview

### Method 1: Python Simple Server (Easiest)

```bash
# Navigate to the website directory
cd /Users/matthewreichard/git/macos-focus-utility/website

# Start a local server on port 8000
python3 -m http.server 8000

# Open in browser
open http://localhost:8000
```

### Method 2: PHP Server

```bash
cd /Users/matthewreichard/git/macos-focus-utility/website
php -S localhost:8000
open http://localhost:8000
```

### Method 3: VS Code Live Server

1. Install "Live Server" extension in VS Code
2. Right-click on `index.html`
3. Select "Open with Live Server"

## 🌐 Free Hosting with Custom Domain Options

### Option 1: Vercel (Recommended ⭐)

**Why Vercel:**
- ✅ Best performance (global CDN)
- ✅ Automatic HTTPS
- ✅ Free custom domain support
- ✅ Instant deployments
- ✅ Perfect for static sites

**Steps:**

1. **Create Vercel Account**
   - Go to [vercel.com](https://vercel.com)
   - Sign up with GitHub (free)

2. **Deploy Website**
   ```bash
   # Install Vercel CLI
   npm install -g vercel

   # Navigate to website folder
   cd /Users/matthewreichard/git/macos-focus-utility/website

   # Deploy
   vercel

   # Follow prompts:
   # - Set up and deploy? Yes
   # - Link to existing project? No
   # - Project name: tome-website
   # - Directory: ./
   # - Override settings? No
   ```

3. **Get Free Custom Domain**

   **Option A: Use Vercel's free .vercel.app domain**
   - Instant: `tome-website.vercel.app`
   - Can be customized: `tome.vercel.app`

   **Option B: Free domain from Freenom + Vercel**
   - Get free domain: [freenom.com](https://www.freenom.com) (.tk, .ml, .ga, .cf, .gq)
   - Register domain (e.g., `tome.tk`)
   - In Vercel dashboard:
     - Go to your project → Settings → Domains
     - Add your custom domain
     - Follow DNS configuration instructions
     - Update nameservers at Freenom

   **Option C: Free subdomain from is-a.dev (Developer-focused)**
   - Fork [is-a-dev/register](https://github.com/is-a-dev/register)
   - Create PR with your subdomain (e.g., `tome.is-a.dev`)
   - Point to Vercel deployment
   - Free, clean domain for developers

### Option 2: Netlify

**Why Netlify:**
- ✅ Easy drag-and-drop deployment
- ✅ Free custom domain support
- ✅ Automatic HTTPS
- ✅ Great for static sites

**Steps:**

1. **Create Netlify Account**
   - Go to [netlify.com](https://netlify.com)
   - Sign up with GitHub (free)

2. **Deploy Website**

   **Method A: Drag and Drop**
   - Zip your website folder
   - Go to Netlify dashboard
   - Drag and drop the zip file
   - Done! (gets `random-name.netlify.app`)

   **Method B: CLI**
   ```bash
   # Install Netlify CLI
   npm install -g netlify-cli

   # Navigate to website folder
   cd /Users/matthewreichard/git/macos-focus-utility/website

   # Deploy
   netlify deploy --prod
   ```

3. **Custom Domain Options**
   - Same as Vercel (Freenom .tk domains work perfectly)
   - Or use Netlify's domain: `tome.netlify.app`

### Option 3: GitHub Pages + Freenom

**Why GitHub Pages:**
- ✅ Completely free
- ✅ Easy git integration
- ✅ Supports custom domains
- ✅ Reliable GitHub infrastructure

**Steps:**

1. **Create GitHub Repository**
   ```bash
   cd /Users/matthewreichard/git/macos-focus-utility/website

   # Initialize git if not already
   git init
   git add .
   git commit -m "Initial TOME website"

   # Create new repo on GitHub: tome-website
   # Then push:
   git remote add origin https://github.com/YOUR_USERNAME/tome-website.git
   git branch -M main
   git push -u origin main
   ```

2. **Enable GitHub Pages**
   - Go to repository Settings → Pages
   - Source: Deploy from a branch → main → root
   - Save
   - Site will be at: `YOUR_USERNAME.github.io/tome-website`

3. **Add Custom Domain**
   - Get free domain from [Freenom](https://www.freenom.com) (.tk, .ml, .ga)
   - In repo, create file `CNAME` with your domain:
     ```
     tome.tk
     ```
   - At Freenom, set DNS records:
     ```
     A Record: 185.199.108.153
     A Record: 185.199.109.153
     A Record: 185.199.110.153
     A Record: 185.199.111.153
     ```
   - Wait 24-48 hours for DNS propagation

### Option 4: Cloudflare Pages

**Why Cloudflare Pages:**
- ✅ Ultra-fast global CDN
- ✅ Free unlimited bandwidth
- ✅ Great with custom domains
- ✅ Excellent security

**Steps:**

1. **Create Cloudflare Account**
   - Go to [pages.cloudflare.com](https://pages.cloudflare.com)
   - Sign up (free)

2. **Deploy**
   - Connect GitHub repository
   - Or direct upload
   - Configure: Build command (none), Output directory (/)
   - Deploy

3. **Custom Domain**
   - Freenom domain works great
   - Cloudflare handles DNS automatically

## 🎨 Customization

### Update Images
Replace files in:
- `assets/images/` - Product photos, logos
- `assets/screenshots/` - Software UI screenshots
- `assets/renders/` - 3D renders

### Modify Colors
Edit `styles.css` CSS variables:
```css
:root {
    --writer-green: #00ff88;
    --workshop-purple: #9d00ff;
    --coffeeshop-orange: #ff8800;
    --garden-green: #00ff44;
}
```

### Update Content
Edit `index.html` - all text content is in semantic HTML sections.

## 📦 File Structure

```
website/
├── index.html          # Main HTML file
├── styles.css          # All styles and animations
├── script.js           # JavaScript animations
├── README.md           # This file
├── assets/
│   ├── images/         # Photos and logos
│   ├── screenshots/    # Software screenshots
│   └── renders/        # 3D hardware renders
└── Tome V3 v1.fbx      # 3D model (for future use)
```

## 🔧 Technologies Used

- **HTML5**: Semantic markup
- **CSS3**: Custom properties, Grid, Flexbox, backdrop-filter
- **JavaScript (ES6+)**: Modern syntax
- **GSAP 3**: Smooth animations and ScrollTrigger
- **Three.js**: Ready for 3D enhancements

## 🎯 Performance Tips

1. **Image Optimization**
   ```bash
   # Install imagemin-cli
   npm install -g imagemin-cli imagemin-pngquant imagemin-mozjpeg

   # Optimize images
   imagemin assets/**/*.{jpg,png} --out-dir=assets/optimized --plugin=pngquant --plugin=mozjpeg
   ```

2. **Enable Compression**
   - Vercel/Netlify do this automatically
   - For GitHub Pages, images should be optimized beforehand

3. **CDN Benefits**
   - All recommended hosts use global CDNs
   - Automatic edge caching
   - HTTPS enabled by default

## 🚨 Troubleshooting

### Images not loading locally?
- Make sure you're running a local server (not just opening index.html)
- Check file paths in HTML

### Animations not working?
- Check browser console for errors
- Ensure GSAP CDN links are accessible
- Try disabling browser extensions

### Custom domain not working?
- DNS propagation takes 24-48 hours
- Verify DNS records are correct
- Clear browser cache
- Try incognito mode

## 📱 Browser Support

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Mobile browsers (iOS Safari, Chrome Mobile)

## 🎨 Design Philosophy

This website matches TOME's software aesthetic:
- **Pure black backgrounds** (#000000)
- **Glassmorphic effects** with subtle borders
- **White text** with varying opacity
- **Helvetica Neue** typography
- **Smooth, spring-like animations**
- **Minimal but impactful** visual design

## 📝 Best Free Domain Extensions

1. **.tk** - Tokelau (most popular free option)
2. **.ml** - Mali
3. **.ga** - Gabon
4. **.cf** - Central African Republic
5. **.gq** - Equatorial Guinea
6. **.is-a.dev** - Developer-focused subdomain (clean)

**Recommendations:**
- **For serious project**: Get `.tk` from Freenom (free for 12 months, renewable)
- **For portfolio**: Use `tome.is-a.dev` (looks professional)
- **Quick deployment**: Use Vercel's `tome.vercel.app` (clean, fast)

## 🚀 Quick Start (Fastest Method)

```bash
# 1. Navigate to website folder
cd /Users/matthewreichard/git/macos-focus-utility/website

# 2. Preview locally
python3 -m http.server 8000

# 3. Deploy to Vercel (if you want)
npx vercel

# That's it! Your site is live at: tome-website.vercel.app
```

## 📞 Support

For issues or questions:
1. Check browser console for errors
2. Verify all asset paths are correct
3. Ensure local server is running
4. Test in incognito mode

---

**Built with ❤️ for TOME - The Focus Revolution**
