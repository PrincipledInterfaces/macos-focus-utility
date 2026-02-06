// ========================================
// TOME Website JavaScript
// Smooth animations and interactions
// ========================================

// Register GSAP plugins
gsap.registerPlugin(ScrollTrigger);

// ========================================
// Smooth Scroll & Navigation
// ========================================

// Smooth scroll for all internal links (navigation and footer)
document.querySelectorAll('a[href^="#"]').forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        const targetId = link.getAttribute('href');
        const target = document.querySelector(targetId);
        if (target) {
            // Calculate position with offset for fixed nav
            const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - 80;

            window.scrollTo({
                top: targetPosition,
                behavior: 'smooth'
            });
        }
    });
});

// Navigation background on scroll
ScrollTrigger.create({
    start: 'top top',
    end: 'bottom bottom',
    onUpdate: (self) => {
        const nav = document.querySelector('.nav');
        if (self.scroll() > 100) {
            nav.style.background = 'rgba(0, 0, 0, 0.95)';
        } else {
            nav.style.background = 'rgba(0, 0, 0, 0.7)';
        }
    }
});

// ========================================
// Scroll-Triggered Animations
// ========================================

// Animate section titles
gsap.utils.toArray('.section-title').forEach(title => {
    gsap.from(title, {
        scrollTrigger: {
            trigger: title,
            start: 'top 80%',
            end: 'top 50%',
            scrub: 1
        },
        y: 50,
        opacity: 0
    });
});

// Animate feature cards
gsap.utils.toArray('.feature-card').forEach((card, i) => {
    gsap.from(card, {
        scrollTrigger: {
            trigger: card,
            start: 'top 85%',
            end: 'top 60%'
        },
        y: 60,
        opacity: 0,
        duration: 0.8,
        delay: i * 0.1,
        ease: "power3.out"
    });
});

// Animate ritual section
ScrollTrigger.create({
    trigger: '.ritual-section',
    start: 'top 70%',
    onEnter: () => {
        gsap.from('.ritual-image', {
            x: -100,
            opacity: 0,
            duration: 1,
            ease: "power3.out"
        });
        gsap.from('.ritual-text', {
            x: 100,
            opacity: 0,
            duration: 1,
            ease: "power3.out",
            delay: 0.2
        });
    }
});

// Animate video section
ScrollTrigger.create({
    trigger: '.video-section',
    start: 'top 70%',
    onEnter: () => {
        gsap.from('.video-wrapper', {
            scale: 0.95,
            opacity: 0,
            duration: 1,
            ease: "power3.out"
        });
    }
});

// Animate environment cards
gsap.utils.toArray('.environment-card').forEach((card, i) => {
    const visual = card.querySelector('.environment-visual');
    const content = card.querySelector('.environment-content');
    const isEven = i % 2 === 0;

    ScrollTrigger.create({
        trigger: card,
        start: 'top 75%',
        onEnter: () => {
            gsap.from(visual, {
                x: isEven ? -80 : 80,
                opacity: 0,
                duration: 1,
                ease: "power3.out"
            });
            gsap.from(content, {
                x: isEven ? 80 : -80,
                opacity: 0,
                duration: 1,
                delay: 0.2,
                ease: "power3.out"
            });
        }
    });

    // Parallax effect on scroll
    gsap.to(visual, {
        scrollTrigger: {
            trigger: card,
            start: 'top bottom',
            end: 'bottom top',
            scrub: 1
        },
        y: -30
    });
});

// Animate intelligence cards
gsap.utils.toArray('.intel-card').forEach((card, i) => {
    gsap.from(card, {
        scrollTrigger: {
            trigger: card,
            start: 'top 85%',
            end: 'top 60%'
        },
        y: 60,
        opacity: 0,
        duration: 0.8,
        delay: i * 0.15,
        ease: "power3.out"
    });
});

// Animate planning showcase
ScrollTrigger.create({
    trigger: '.planning-showcase',
    start: 'top 70%',
    onEnter: () => {
        gsap.from('.planning-image', {
            scale: 0.9,
            opacity: 0,
            duration: 1,
            ease: "power3.out"
        });
        gsap.from('.planning-text', {
            x: 100,
            opacity: 0,
            duration: 1,
            delay: 0.3,
            ease: "power3.out"
        });
    }
});

// Animate experience section
ScrollTrigger.create({
    trigger: '.experience-showcase',
    start: 'top 70%',
    onEnter: () => {
        gsap.from('.experience-image', {
            scale: 0.95,
            opacity: 0,
            duration: 1.2,
            ease: "power3.out"
        });
        gsap.from('.experience-large', {
            y: 40,
            opacity: 0,
            duration: 1,
            delay: 0.4,
            ease: "power3.out"
        });
    }
});

// ========================================
// Hardware Image Parallax
// ========================================

gsap.to('.hero-hardware', {
    scrollTrigger: {
        trigger: '.hero',
        start: 'top top',
        end: 'bottom top',
        scrub: 1.5
    },
    y: 150,
    scale: 0.9,
    opacity: 0.3
});

// Glow ring animation
gsap.to('.glow-ring', {
    scrollTrigger: {
        trigger: '.hero',
        start: 'top top',
        end: 'bottom top',
        scrub: 1
    },
    scale: 1.5,
    opacity: 0
});

// ========================================
// Interactive Hover Effects
// ========================================

// Environment card hover effects
document.querySelectorAll('.environment-card').forEach(card => {
    const visual = card.querySelector('.environment-visual');

    card.addEventListener('mouseenter', () => {
        gsap.to(visual, {
            scale: 1.02,
            duration: 0.6,
            ease: "power2.out"
        });
    });

    card.addEventListener('mouseleave', () => {
        gsap.to(visual, {
            scale: 1,
            duration: 0.6,
            ease: "power2.out"
        });
    });
});

// Feature card magnetic effect
document.querySelectorAll('.feature-card').forEach(card => {
    card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;

        gsap.to(card, {
            x: x * 0.1,
            y: y * 0.1,
            duration: 0.4,
            ease: "power2.out"
        });
    });

    card.addEventListener('mouseleave', () => {
        gsap.to(card, {
            x: 0,
            y: 0,
            duration: 0.6,
            ease: "power2.out"
        });
    });
});

// Intel card hover glow
document.querySelectorAll('.intel-card').forEach(card => {
    card.addEventListener('mouseenter', () => {
        gsap.to(card, {
            boxShadow: '0 20px 60px rgba(255, 255, 255, 0.1), inset 0 1px 0 rgba(255, 255, 255, 0.2)',
            duration: 0.4
        });
    });

    card.addEventListener('mouseleave', () => {
        gsap.to(card, {
            boxShadow: '0 8px 32px rgba(0, 0, 0, 0.3), inset 0 1px 0 rgba(255, 255, 255, 0.1)',
            duration: 0.4
        });
    });
});

// ========================================
// Cursor Enhancement (optional)
// ========================================

const cursor = document.createElement('div');
cursor.className = 'custom-cursor';
cursor.style.cssText = `
    position: fixed;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.5);
    pointer-events: none;
    z-index: 9999;
    mix-blend-mode: difference;
    transition: transform 0.15s ease, opacity 0.15s ease;
    display: none;
`;
document.body.appendChild(cursor);

// Only show custom cursor on desktop
if (window.matchMedia('(min-width: 1024px)').matches) {
    cursor.style.display = 'block';

    document.addEventListener('mousemove', (e) => {
        gsap.to(cursor, {
            x: e.clientX - 5,
            y: e.clientY - 5,
            duration: 0.15
        });
    });

    // Cursor interactions
    const interactiveElements = document.querySelectorAll('a, button, .feature-card, .environment-visual');
    interactiveElements.forEach(el => {
        el.addEventListener('mouseenter', () => {
            gsap.to(cursor, {
                scale: 2,
                opacity: 0.8,
                duration: 0.3
            });
        });

        el.addEventListener('mouseleave', () => {
            gsap.to(cursor, {
                scale: 1,
                opacity: 0.5,
                duration: 0.3
            });
        });
    });
}

// ========================================
// Performance Optimizations
// ========================================

// Lazy load images
if ('IntersectionObserver' in window) {
    const imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const img = entry.target;
                if (img.dataset.src) {
                    img.src = img.dataset.src;
                    img.removeAttribute('data-src');
                }
                imageObserver.unobserve(img);
            }
        });
    });

    document.querySelectorAll('img[data-src]').forEach(img => {
        imageObserver.observe(img);
    });
}

// Smooth scroll performance
let scrollTimeout;
window.addEventListener('scroll', () => {
    document.body.classList.add('scrolling');

    clearTimeout(scrollTimeout);
    scrollTimeout = setTimeout(() => {
        document.body.classList.remove('scrolling');
    }, 200);
});

// Reduce scroll listeners for better performance
ScrollTrigger.config({
    limitCallbacks: true,
    syncInterval: 150
});

// ========================================
// Initialize on Load
// ========================================

window.addEventListener('load', () => {
    // Remove loading class if you add one
    document.body.classList.add('loaded');

    // Refresh ScrollTrigger after all images loaded
    ScrollTrigger.refresh();

    console.log('🎯 TOME website loaded successfully');
});

// Refresh ScrollTrigger on resize
let resizeTimeout;
window.addEventListener('resize', () => {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(() => {
        ScrollTrigger.refresh();
    }, 250);
});

// ========================================
// Accessibility
// ========================================

// Respect reduced motion preferences
if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    ScrollTrigger.getAll().forEach(st => st.kill());
    gsap.globalTimeline.clear();
}

// Focus visible for keyboard navigation
document.addEventListener('keydown', (e) => {
    if (e.key === 'Tab') {
        document.body.classList.add('keyboard-nav');
    }
});

document.addEventListener('mousedown', () => {
    document.body.classList.remove('keyboard-nav');
});
