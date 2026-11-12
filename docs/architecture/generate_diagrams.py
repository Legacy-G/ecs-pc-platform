#!/usr/bin/env python3
"""
Generate Diagrams as Code for the ECS PC Platform.
Produces SVG and PNG assets for:
1. AWS Infrastructure Architecture (VPC, Subnets, ALB, ECS, ECR, SSM, CloudWatch, SNS, S3)
2. CI/CD Deployment Flow (GitHub Actions, Jenkins Controller, ECR, Terraform, ECS, ALB Smoke)
"""

import os

from PIL import Image, ImageDraw, ImageFont


def get_font(size=14, bold=False):
    # Try common system fonts on Windows/Linux
    candidates = [
        "arialbd.ttf" if bold else "arial.ttf",
        "segoeuib.ttf" if bold else "segoeui.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for c in candidates:
        try:
            return ImageFont.truetype(c, size)
        except (OSError, RuntimeError):
            continue
    return ImageFont.load_default()


def generate_aws_architecture(output_svg, output_png):
    # Dimensions
    w, h = 1200, 800

    # SVG generation
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">
  <style>
    text {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; }}
    .title {{ font-size: 20px; font-weight: bold; fill: #1e293b; }}
    .subtitle {{ font-size: 13px; fill: #64748b; }}
    .boundary-title {{ font-size: 14px; font-weight: 600; fill: #334155; }}
    .box-title {{ font-size: 14px; font-weight: bold; fill: #0f172a; }}
    .box-desc {{ font-size: 11px; fill: #475569; }}
    .edge-label {{ font-size: 11px; font-weight: 500; fill: #0284c7; }}
  </style>

  <!-- Background -->
  <rect width="{w}" height="{h}" fill="#f8fafc" />

  <!-- Header -->
  <text x="40" y="45" class="title">AWS Infrastructure Architecture - Dev Stack</text>
  <text x="40" y="68" class="subtitle">Region: eu-north-1 | Single-tenant containerized API with ALB, Fargate, and observability</text>

  <!-- AWS Cloud Boundary -->
  <rect x="40" y="90" width="1120" height="670" rx="12" fill="#ffffff" stroke="#cbd5e1" stroke-width="2" />
  <rect x="40" y="90" width="180" height="28" rx="4" fill="#0f172a" />
  <text x="50" y="109" fill="#ffffff" font-size="12px" font-weight="bold">AWS Cloud (eu-north-1)</text>

  <!-- External S3 State & SSM & ECR & Observability & Budgets (Outside VPC) -->
  <g transform="translate(60, 140)">
    <!-- S3 State Backend & AWS Budgets -->
    <rect x="0" y="0" width="220" height="110" rx="8" fill="#f1f5f9" stroke="#94a3b8" stroke-width="1.5" />
    <text x="15" y="24" class="box-title">S3 Backend &amp; Budgets</text>
    <text x="15" y="44" class="box-desc">S3: damolak-tfstate-*-eu-north-1</text>
    <text x="15" y="64" class="box-desc">Lockfile Locking, Encrypted</text>
    <text x="15" y="84" class="box-desc">Budget: $35 alert / $40 limit</text>
    <text x="15" y="102" class="box-desc">IAM CI: jenkins-ci (Boundary)</text>

    <!-- ECR Repository -->
    <rect x="0" y="125" width="220" height="95" rx="8" fill="#f1f5f9" stroke="#94a3b8" stroke-width="1.5" />
    <text x="15" y="148" class="box-title">Amazon ECR</text>
    <text x="15" y="168" class="box-desc">Repository: damolak-api</text>
    <text x="15" y="188" class="box-desc">Tag Immutability: ENABLED</text>
    <text x="15" y="208" class="box-desc">Scan on Push (Basic Scan)</text>

    <!-- SSM Parameter Store -->
    <rect x="0" y="235" width="220" height="90" rx="8" fill="#f1f5f9" stroke="#94a3b8" stroke-width="1.5" />
    <text x="15" y="258" class="box-title">SSM Parameter Store</text>
    <text x="15" y="278" class="box-desc">Path: /damolak/dev/api-key</text>
    <text x="15" y="298" class="box-desc">Type: SecureString (KMS)</text>
    <text x="15" y="316" class="box-desc">In-memory decryption</text>

    <!-- Observability / SNS -->
    <rect x="0" y="340" width="220" height="250" rx="8" fill="#f1f5f9" stroke="#94a3b8" stroke-width="1.5" />
    <text x="15" y="364" class="box-title">Observability &amp; Alarms</text>
    <text x="15" y="384" class="box-desc">Log Group: /ecs/damolak-dev</text>
    <text x="15" y="404" class="box-desc">Metric Filter: damolak-dev-json-error-filter</text>
    <text x="15" y="424" class="box-desc">5 CloudWatch Metric Alarms:</text>
    <text x="15" y="444" class="box-desc">- damolak-dev-alb-5xx</text>
    <text x="15" y="462" class="box-desc">- damolak-dev-healthy-hosts-low</text>
    <text x="15" y="480" class="box-desc">- damolak-dev-unhealthy-hosts</text>
    <text x="15" y="498" class="box-desc">- damolak-dev-cpu-high</text>
    <text x="15" y="516" class="box-desc">- damolak-dev-app-log-errors</text>
    <text x="15" y="542" class="box-title" font-size="12px">SNS: damolak-dev-alerts</text>
    <text x="15" y="562" class="box-desc">Dashboard: damolak-dev-overview</text>
  </g>

  <!-- VPC Boundary -->
  <rect x="310" y="140" width="820" height="590" rx="10" fill="#f8fafc" stroke="#2563eb" stroke-width="2" stroke-dasharray="6,6" />
  <rect x="310" y="140" width="240" height="26" rx="4" fill="#2563eb" />
  <text x="320" y="158" fill="#ffffff" font-size="12px" font-weight="bold">VPC: 10.20.0.0/16 (damolak-dev-vpc)</text>

  <!-- Internet Gateway -->
  <rect x="330" y="185" width="780" height="40" rx="6" fill="#e0f2fe" stroke="#0284c7" stroke-width="1.5" />
  <text x="350" y="210" font-size="13px" font-weight="bold" fill="#0369a1">Internet Gateway (IGW) - Route: 0.0.0.0/0 -&gt; igw-0c8034af596b656e4</text>

  <!-- Public Subnet 1 (eu-north-1a) -->
  <rect x="330" y="245" width="375" height="465" rx="8" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5" />
  <rect x="330" y="245" width="260" height="24" rx="4" fill="#64748b" />
  <text x="340" y="262" fill="#ffffff" font-size="11px" font-weight="bold">Public Subnet 1 (10.20.0.0/24, eu-north-1a)</text>

  <!-- Public Subnet 2 (eu-north-1b) -->
  <rect x="735" y="245" width="375" height="465" rx="8" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5" />
  <rect x="735" y="245" width="260" height="24" rx="4" fill="#64748b" />
  <text x="745" y="262" fill="#ffffff" font-size="11px" font-weight="bold">Public Subnet 2 (10.20.1.0/24, eu-north-1b)</text>

  <!-- ALB Spanning Subnets -->
  <rect x="350" y="285" width="740" height="110" rx="8" fill="#eff6ff" stroke="#3b82f6" stroke-width="1.5" />
  <text x="370" y="310" class="box-title">Application Load Balancer (ALB: damolak-dev-alb)</text>
  <text x="370" y="330" class="box-desc">Public IPv4: Dual-AZ round-robin | Security Group: Ingress 80/tcp from 0.0.0.0/0</text>
  <text x="370" y="350" class="box-desc">HTTP Listener (Port 80): Default 404 Fixed-Response | Rule (Prio 100): /* -&gt; Target Group</text>
  <text x="370" y="370" class="box-desc">Target Group (damolak-dev-api-tg: Port 8000, deregistration_delay=30s) | Health Check: /api/v1/health/</text>

  <!-- ECS Fargate Service -->
  <rect x="350" y="420" width="740" height="270" rx="8" fill="#fdf4ff" stroke="#a855f7" stroke-width="1.5" />
  <text x="370" y="445" class="box-title">ECS Cluster: damolak-dev-cluster | Service: damolak-dev-api (Fargate)</text>
  <text x="370" y="465" class="box-desc">Capacity: 1 Task (0.25 vCPU, 512 MB) | AutoScaling: 1-2 Tasks (Target Tracking: 70% CPU)</text>
  <text x="370" y="485" class="box-desc">Task Security Group: Ingress 8000/tcp from ALB SG ONLY | Egress: 443/tcp (ECR, SSM, Logs)</text>

  <!-- Fargate Task Box -->
  <rect x="380" y="510" width="680" height="160" rx="6" fill="#ffffff" stroke="#c084fc" stroke-width="1.5" />
  <text x="400" y="535" class="box-title" font-size="13px">Fargate Task Container: damolak-api:0.1.1</text>
  <text x="400" y="555" class="box-desc">- Non-root execution: appuser (UID 10001, GID 10001)</text>
  <text x="400" y="575" class="box-desc">- Read-only root filesystem with tmpfs mounted at /tmp</text>
  <text x="400" y="595" class="box-desc">- Secrets: X-API-Key injected into memory via SSM Parameter Store at startup</text>
  <text x="400" y="615" class="box-desc">- Reverse Proxy Config: FORWARDED_ALLOW_IPS="10.20.0.0/16" (logs real client IP from X-Forwarded-For)</text>
  <text x="400" y="635" class="box-desc">- Container stopTimeout: 30s (matches ALB deregistration delay for zero dropped in-flight requests)</text>

  <!-- Traffic Flow Arrows (Paths) -->
  <!-- Client Traffic -->
  <path d="M 720 70 L 720 185" fill="none" stroke="#0284c7" stroke-width="2.5" marker-end="url(#arrow)" />
  <text x="730" y="130" class="edge-label">Client HTTP (Port 80)</text>

  <!-- ALB to Task -->
  <path d="M 720 395 L 720 510" fill="none" stroke="#2563eb" stroke-width="2.5" />
  <text x="730" y="415" class="edge-label">HTTP:8000 (Forwarded)</text>

  <!-- Task to ECR/SSM/Logs -->
  <path d="M 380 590 L 280 590 L 280 440 L 220 440" fill="none" stroke="#64748b" stroke-width="1.5" stroke-dasharray="4,4" />
  <text x="235" y="520" font-size="10px" fill="#64748b">Logs / Metrics</text>

  <path d="M 380 590 L 280 590 L 280 310 L 220 310" fill="none" stroke="#64748b" stroke-width="1.5" stroke-dasharray="4,4" />
  <text x="240" y="350" font-size="10px" fill="#64748b">SSM GetSecret</text>

  <path d="M 380 590 L 280 590 L 280 185 L 220 185" fill="none" stroke="#64748b" stroke-width="1.5" stroke-dasharray="4,4" />
  <text x="245" y="210" font-size="10px" fill="#64748b">ECR Pull</text>

</svg>'''

    with open(output_svg, "w", encoding="utf-8") as f:
        f.write(svg)

    # PNG generation via PIL
    img = Image.new("RGB", (w, h), color=(248, 250, 252))
    draw = ImageDraw.Draw(img)

    f_title = get_font(20, bold=True)
    f_sub = get_font(13)
    f_box_t = get_font(13, bold=True)
    f_box_d = get_font(11)

    # Header
    draw.text(
        (40, 30),
        "AWS Infrastructure Architecture - Dev Stack",
        fill=(30, 41, 59),
        font=f_title,
    )
    draw.text(
        (40, 60),
        "Region: eu-north-1 | Single-tenant containerized API with ALB, Fargate, and observability",
        fill=(100, 116, 139),
        font=f_sub,
    )

    # AWS Cloud Boundary
    draw.rectangle(
        [40, 90, 1160, 760], fill=(255, 255, 255), outline=(203, 213, 225), width=2
    )
    draw.rectangle([40, 90, 220, 116], fill=(15, 23, 42))
    draw.text((50, 95), "AWS Cloud (eu-north-1)", fill=(255, 255, 255), font=f_box_t)

    # S3 State & Budgets
    draw.rectangle(
        [60, 140, 280, 245], fill=(241, 245, 249), outline=(148, 163, 184), width=1
    )
    draw.text((75, 148), "S3 Backend & Budgets", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (75, 170),
        "damolak-tfstate-*-eu-north-1\nLockfile Locking, Encrypted\nBudget: $35 alert / $40 limit\nIAM CI: jenkins-ci (Boundary)",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    # ECR
    draw.rectangle(
        [60, 255, 280, 350], fill=(241, 245, 249), outline=(148, 163, 184), width=1
    )
    draw.text((75, 263), "Amazon ECR", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (75, 285),
        "Repository: damolak-api\nTag Immutability: ENABLED\nScan on Push (Basic Scan)",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    # SSM
    draw.rectangle(
        [60, 360, 280, 450], fill=(241, 245, 249), outline=(148, 163, 184), width=1
    )
    draw.text((75, 368), "SSM Parameter Store", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (75, 390),
        "Path: /damolak/dev/api-key\nType: SecureString (KMS)\nIn-memory decryption",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    # Observability
    draw.rectangle(
        [60, 460, 280, 730], fill=(241, 245, 249), outline=(148, 163, 184), width=1
    )
    draw.text((75, 470), "Observability & Alarms", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (75, 495),
        "Log Group: /ecs/damolak-dev\nFilter: damolak-dev-json-error-filter\n5 CloudWatch Metric Alarms:\n- damolak-dev-alb-5xx\n- damolak-dev-healthy-hosts-low\n- damolak-dev-unhealthy-hosts\n- damolak-dev-cpu-high\n- damolak-dev-app-log-errors\nSNS: damolak-dev-alerts\nDashboard: damolak-dev-overview",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    # VPC Boundary
    draw.rectangle(
        [310, 140, 1130, 730], fill=(248, 250, 252), outline=(37, 99, 235), width=2
    )
    draw.rectangle([310, 140, 550, 165], fill=(37, 99, 235))
    draw.text(
        (320, 145),
        "VPC: 10.20.0.0/16 (damolak-dev-vpc)",
        fill=(255, 255, 255),
        font=f_box_t,
    )

    # IGW
    draw.rectangle(
        [330, 180, 1110, 220], fill=(224, 242, 254), outline=(2, 132, 199), width=1
    )
    draw.text(
        (350, 192),
        "Internet Gateway (IGW) - Route: 0.0.0.0/0 -> igw-0c8034af596b656e4",
        fill=(3, 105, 161),
        font=f_box_t,
    )

    # Subnets
    draw.rectangle(
        [330, 235, 705, 700], fill=(255, 255, 255), outline=(148, 163, 184), width=1
    )
    draw.rectangle([330, 235, 600, 260], fill=(100, 116, 139))
    draw.text(
        (340, 240),
        "Public Subnet 1 (10.20.0.0/24, eu-north-1a)",
        fill=(255, 255, 255),
        font=f_box_d,
    )

    draw.rectangle(
        [735, 235, 1110, 700], fill=(255, 255, 255), outline=(148, 163, 184), width=1
    )
    draw.rectangle([735, 235, 1005, 260], fill=(100, 116, 139))
    draw.text(
        (745, 240),
        "Public Subnet 2 (10.20.1.0/24, eu-north-1b)",
        fill=(255, 255, 255),
        font=f_box_d,
    )

    # ALB
    draw.rectangle(
        [350, 275, 1090, 385], fill=(239, 246, 255), outline=(59, 130, 246), width=1
    )
    draw.text(
        (370, 290),
        "Application Load Balancer (ALB: damolak-dev-alb)",
        fill=(15, 23, 42),
        font=f_box_t,
    )
    draw.text(
        (370, 315),
        "Public IPv4: Dual-AZ round-robin | Security Group: Ingress 80/tcp from 0.0.0.0/0\nListener (80/tcp): Default 404 Response | Rule (Prio 100): /* -> Target Group (8000/tcp, delay=30s)\nHealth Check: /api/v1/health/ (interval=15s, healthy=2, unhealthy=3, timeout=5s)",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    # ECS Fargate Service
    draw.rectangle(
        [350, 410, 1090, 680], fill=(253, 244, 255), outline=(168, 85, 247), width=1
    )
    draw.text(
        (370, 425),
        "ECS Cluster: damolak-dev-cluster | Service: damolak-dev-api (Fargate)",
        fill=(15, 23, 42),
        font=f_box_t,
    )
    draw.text(
        (370, 450),
        "Capacity: 1 Task (0.25 vCPU, 512 MB) | AutoScaling: 1-2 Tasks (Target Tracking: 70% CPU)\nTask SG: Ingress 8000/tcp from ALB SG ONLY | Egress: 443/tcp (ECR, SSM, CloudWatch)",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    # Fargate Task Container
    draw.rectangle(
        [380, 500, 1060, 660], fill=(255, 255, 255), outline=(192, 132, 252), width=1
    )
    draw.text(
        (400, 515),
        "Fargate Task Container: damolak-api:0.1.1",
        fill=(15, 23, 42),
        font=f_box_t,
    )
    draw.text(
        (400, 540),
        '- Non-root execution: appuser (UID 10001, GID 10001)\n- Read-only root filesystem with tmpfs mounted at /tmp\n- Secrets: X-API-Key injected into memory via SSM Parameter Store at startup\n- Reverse Proxy Config: FORWARDED_ALLOW_IPS="10.20.0.0/16" (logs real client IP)\n- Container stopTimeout: 30s (matches ALB deregistration delay)',
        fill=(71, 85, 105),
        font=f_box_d,
    )

    img.save(output_png, "PNG")
    print(f"Generated {output_svg} and {output_png}")


def generate_cicd_flow(output_svg, output_png):
    w, h = 1200, 750

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">
  <style>
    text {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; }}
    .title {{ font-size: 20px; font-weight: bold; fill: #1e293b; }}
    .subtitle {{ font-size: 13px; fill: #64748b; }}
    .box-title {{ font-size: 14px; font-weight: bold; fill: #0f172a; }}
    .box-desc {{ font-size: 11px; fill: #475569; }}
    .stage-title {{ font-size: 13px; font-weight: bold; fill: #1e293b; }}
  </style>

  <!-- Background -->
  <rect width="{w}" height="{h}" fill="#f8fafc" />

  <!-- Header -->
  <text x="40" y="45" class="title">End-to-End CI/CD Pipeline &amp; Promotion Architecture</text>
  <text x="40" y="68" class="subtitle">GitHub Actions (Offline Quality Gates) -&gt; Main Branch Merge -&gt; Jenkins Controller (Automated Cloud Deployment)</text>

  <!-- Developer Workstation Boundary -->
  <rect x="40" y="100" width="240" height="600" rx="10" fill="#ffffff" stroke="#94a3b8" stroke-width="1.5" />
  <rect x="40" y="100" width="240" height="30" rx="4" fill="#334155" />
  <text x="55" y="120" fill="#ffffff" font-size="12px" font-weight="bold">1. Developer Workstation</text>

  <rect x="55" y="150" width="210" height="90" rx="6" fill="#f8fafc" stroke="#cbd5e1" />
  <text x="65" y="175" class="box-title">Feature Branch</text>
  <text x="65" y="195" class="box-desc">All edits made on git</text>
  <text x="65" y="215" class="box-desc">feature/ or fix/ branches</text>

  <rect x="55" y="260" width="210" height="150" rx="6" fill="#f8fafc" stroke="#cbd5e1" />
  <text x="65" y="285" class="box-title">Pre-Commit Hooks</text>
  <text x="65" y="305" class="box-desc">- check-hygiene.sh (credentials)</text>
  <text x="65" y="325" class="box-desc">- gitleaks (secrets &amp; accounts)</text>
  <text x="65" y="345" class="box-desc">- ruff (lint &amp; format)</text>
  <text x="65" y="365" class="box-desc">- shellcheck &amp; yamllint</text>
  <text x="65" y="385" class="box-desc">- terraform fmt</text>

  <rect x="55" y="430" width="210" height="110" rx="6" fill="#f8fafc" stroke="#cbd5e1" />
  <text x="65" y="455" class="box-title">Pull Request (gh pr)</text>
  <text x="65" y="475" class="box-desc">Branch protection blocks</text>
  <text x="65" y="495" class="box-desc">direct pushes to main</text>
  <text x="65" y="515" class="box-desc">Requires 3 CI checks</text>

  <!-- GitHub Actions Boundary -->
  <rect x="310" y="100" width="260" height="600" rx="10" fill="#ffffff" stroke="#2563eb" stroke-width="1.5" />
  <rect x="310" y="100" width="260" height="30" rx="4" fill="#2563eb" />
  <text x="325" y="120" fill="#ffffff" font-size="12px" font-weight="bold">2. GitHub Actions (PR Gates)</text>

  <rect x="325" y="150" width="230" height="110" rx="6" fill="#eff6ff" stroke="#93c5fd" />
  <text x="335" y="175" class="stage-title">Job 1: Lint, Hygiene &amp; Tests</text>
  <text x="335" y="195" class="box-desc">- check-hygiene.sh</text>
  <text x="335" y="215" class="box-desc">- gitleaks detect</text>
  <text x="335" y="235" class="box-desc">- pytest services/api/tests (22)</text>

  <rect x="325" y="280" width="230" height="130" rx="6" fill="#eff6ff" stroke="#93c5fd" />
  <text x="335" y="305" class="stage-title">Job 2: Container &amp; Scan</text>
  <text x="335" y="325" class="box-desc">- hadolint Dockerfile</text>
  <text x="335" y="345" class="box-desc">- docker buildx build</text>
  <text x="335" y="365" class="box-desc">- offline curl-less smoke test</text>
  <text x="335" y="385" class="box-desc">- trivy security scan</text>

  <rect x="325" y="430" width="230" height="120" rx="6" fill="#eff6ff" stroke="#93c5fd" />
  <text x="335" y="455" class="stage-title">Job 3: Terraform Validate</text>
  <text x="335" y="475" class="box-desc">- terraform fmt -check</text>
  <text x="335" y="495" class="box-desc">- terraform validate (offline)</text>
  <text x="335" y="515" class="box-desc">- checkov policy audit</text>

  <rect x="325" y="570" width="230" height="110" rx="6" fill="#f0fdf4" stroke="#86efac" />
  <text x="335" y="595" class="stage-title" fill="#166534">Merge to Main</text>
  <text x="335" y="615" class="box-desc">- Merge Commit (non-squash)</text>
  <text x="335" y="635" class="box-desc">- Trigger for deployment</text>
  <text x="335" y="655" class="box-desc">- Zero AWS writes from GitHub</text>

  <!-- Jenkins Controller Boundary -->
  <rect x="600" y="100" width="560" height="600" rx="10" fill="#ffffff" stroke="#059669" stroke-width="1.5" />
  <rect x="600" y="100" width="560" height="30" rx="4" fill="#059669" />
  <text x="615" y="120" fill="#ffffff" font-size="12px" font-weight="bold">3. Jenkins Controller: Automated Cloud Deployment (damolak-api-pipeline)</text>

  <!-- Pipeline Stages -->
  <rect x="620" y="150" width="520" height="50" rx="6" fill="#f0fdf4" stroke="#bbf7d0" />
  <text x="635" y="180" class="stage-title">Checkout (SCM Polling) | Hygiene Lint | Unit Tests (Pytest)</text>

  <rect x="620" y="215" width="520" height="60" rx="6" fill="#f0fdf4" stroke="#bbf7d0" />
  <text x="635" y="240" class="stage-title">Build Container</text>
  <text x="635" y="260" class="box-desc">docker buildx build --provenance=false --sbom=false --load -t damolak-api:GIT_SHA</text>

  <rect x="620" y="290" width="520" height="60" rx="6" fill="#f0fdf4" stroke="#bbf7d0" />
  <text x="635" y="315" class="stage-title">Image Security Scan</text>
  <text x="635" y="335" class="box-desc">Trivy vulnerability scan --severity HIGH,CRITICAL --ignore-unfixed (0 CVEs gate)</text>

  <rect x="620" y="365" width="520" height="65" rx="6" fill="#f0fdf4" stroke="#bbf7d0" />
  <text x="635" y="390" class="stage-title">Push to Amazon ECR</text>
  <text x="635" y="410" class="box-desc">Silenced credential pipe (set +x, password-stdin) -&gt; Tag: GIT_SHA pushed to ECR</text>

  <rect x="620" y="445" width="520" height="65" rx="6" fill="#f0fdf4" stroke="#bbf7d0" />
  <text x="635" y="470" class="stage-title">Terraform Validate &amp; Plan (dev)</text>
  <text x="635" y="490" class="box-desc">Dynamic backend.hcl generation -&gt; terraform plan -var="image_tag=GIT_SHA" -out=plan</text>

  <rect x="620" y="525" width="520" height="75" rx="6" fill="#f0fdf4" stroke="#bbf7d0" />
  <text x="635" y="550" class="stage-title">Apply Plan (Rolling Update)</text>
  <text x="635" y="570" class="box-desc">terraform apply jenkins.tfplan -&gt; ECS Task Definition updated -&gt; Rolling Deployment</text>
  <text x="635" y="588" class="box-desc">Circuit Breaker active | Wait for steady state</text>

  <rect x="620" y="615" width="520" height="70" rx="6" fill="#f0fdf4" stroke="#bbf7d0" />
  <text x="635" y="640" class="stage-title">Live ALB Smoke Test &amp; Cleanup</text>
  <text x="635" y="660" class="box-desc">scripts/smoke.sh against dev ALB URL -&gt; 401 unauth, 401 wrong key, 200 SSM key, 404 route</text>
  <text x="635" y="675" class="box-desc">deleteDir() workspace sanitisation</text>

</svg>'''

    with open(output_svg, "w", encoding="utf-8") as f:
        f.write(svg)

    # PNG generation
    img = Image.new("RGB", (w, h), color=(248, 250, 252))
    draw = ImageDraw.Draw(img)

    f_title = get_font(20, bold=True)
    f_sub = get_font(13)
    f_box_t = get_font(13, bold=True)
    f_box_d = get_font(11)

    # Header
    draw.text(
        (40, 30),
        "End-to-End CI/CD Pipeline & Promotion Architecture",
        fill=(30, 41, 59),
        font=f_title,
    )
    draw.text(
        (40, 60),
        "GitHub Actions (Offline Quality Gates) -> Main Branch Merge -> Jenkins Controller (Automated Cloud Deployment)",
        fill=(100, 116, 139),
        font=f_sub,
    )

    # Section 1: Developer Workstation
    draw.rectangle(
        [40, 100, 280, 700], fill=(255, 255, 255), outline=(148, 163, 184), width=1
    )
    draw.rectangle([40, 100, 280, 130], fill=(51, 65, 85))
    draw.text((50, 108), "1. Developer Workstation", fill=(255, 255, 255), font=f_box_t)

    draw.rectangle(
        [55, 150, 265, 240], fill=(248, 250, 252), outline=(203, 213, 225), width=1
    )
    draw.text((65, 165), "Feature Branch", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (65, 190),
        "All edits made on git\nfeature/ or fix/ branches",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [55, 260, 265, 410], fill=(248, 250, 252), outline=(203, 213, 225), width=1
    )
    draw.text((65, 275), "Pre-Commit Hooks", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (65, 300),
        "- check-prose.sh\n- gitleaks detect\n- ruff (lint & format)\n- shellcheck & yamllint\n- terraform fmt",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [55, 430, 265, 540], fill=(248, 250, 252), outline=(203, 213, 225), width=1
    )
    draw.text((65, 445), "Pull Request (gh pr)", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (65, 470),
        "Branch protection blocks\ndirect pushes to main.\nRequires 3 CI checks.",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    # Section 2: GitHub Actions
    draw.rectangle(
        [310, 100, 570, 700], fill=(255, 255, 255), outline=(37, 99, 235), width=1
    )
    draw.rectangle([310, 100, 570, 130], fill=(37, 99, 235))
    draw.text(
        (320, 108), "2. GitHub Actions (PR Gates)", fill=(255, 255, 255), font=f_box_t
    )

    draw.rectangle(
        [325, 150, 555, 260], fill=(239, 246, 255), outline=(147, 197, 253), width=1
    )
    draw.text((335, 165), "Job 1: Lint, Prose & Tests", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (335, 190),
        "- check-prose.sh\n- gitleaks detect\n- pytest unit tests (22)",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [325, 280, 555, 410], fill=(239, 246, 255), outline=(147, 197, 253), width=1
    )
    draw.text((335, 295), "Job 2: Container & Scan", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (335, 320),
        "- hadolint Dockerfile\n- docker buildx build\n- offline smoke test\n- trivy scan (0 CVEs)",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [325, 430, 555, 550], fill=(239, 246, 255), outline=(147, 197, 253), width=1
    )
    draw.text((335, 445), "Job 3: Terraform Validate", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (335, 470),
        "- terraform fmt -check\n- terraform validate\n- checkov policy audit",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [325, 570, 555, 680], fill=(240, 253, 244), outline=(134, 239, 172), width=1
    )
    draw.text((335, 585), "Merge to Main", fill=(22, 101, 52), font=f_box_t)
    draw.text(
        (335, 610),
        "- Merge Commit (non-squash)\n- SCP blocks cloud writes\n- Handoff to Jenkins",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    # Section 3: Jenkins Controller
    draw.rectangle(
        [600, 100, 1160, 700], fill=(255, 255, 255), outline=(5, 150, 105), width=1
    )
    draw.rectangle([600, 100, 1160, 130], fill=(5, 150, 105))
    draw.text(
        (615, 108),
        "3. Jenkins Controller: Automated Cloud Deployment (damolak-api-pipeline)",
        fill=(255, 255, 255),
        font=f_box_t,
    )

    draw.rectangle(
        [620, 150, 1140, 200], fill=(240, 253, 244), outline=(187, 247, 208), width=1
    )
    draw.text(
        (635, 168),
        "Checkout (SCM Polling) | Hygiene Lint | Unit Tests (Pytest)",
        fill=(15, 23, 42),
        font=f_box_t,
    )

    draw.rectangle(
        [620, 215, 1140, 275], fill=(240, 253, 244), outline=(187, 247, 208), width=1
    )
    draw.text((635, 228), "Build Container", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (635, 248),
        "docker buildx build --provenance=false --sbom=false --load -t damolak-api:${GIT_SHA}",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [620, 290, 1140, 350], fill=(240, 253, 244), outline=(187, 247, 208), width=1
    )
    draw.text((635, 303), "Image Security Scan", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (635, 323),
        "Trivy vulnerability scan --severity HIGH,CRITICAL --ignore-unfixed (0 CVEs gate)",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [620, 365, 1140, 430], fill=(240, 253, 244), outline=(187, 247, 208), width=1
    )
    draw.text((635, 378), "Push to Amazon ECR", fill=(15, 23, 42), font=f_box_t)
    draw.text(
        (635, 398),
        "Silenced credential pipe (set +x, password-stdin) -> Tag: ${GIT_SHA} pushed to ECR",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [620, 445, 1140, 510], fill=(240, 253, 244), outline=(187, 247, 208), width=1
    )
    draw.text(
        (635, 458),
        "Terraform Validate & Plan (dev)",
        fill=(15, 23, 42),
        font=f_box_t,
    )
    draw.text(
        (635, 478),
        'Dynamic backend.hcl generation -> terraform plan -var="image_tag=${GIT_SHA}" -out=plan',
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [620, 525, 1140, 600], fill=(240, 253, 244), outline=(187, 247, 208), width=1
    )
    draw.text(
        (635, 538),
        "Apply Plan (Rolling Update)",
        fill=(15, 23, 42),
        font=f_box_t,
    )
    draw.text(
        (635, 558),
        "terraform apply jenkins.tfplan -> ECS Task Definition updated -> Rolling Deployment\nCircuit Breaker active | Wait for steady state",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    draw.rectangle(
        [620, 615, 1140, 685], fill=(240, 253, 244), outline=(187, 247, 208), width=1
    )
    draw.text(
        (635, 628),
        "Live ALB Smoke Test & Cleanup",
        fill=(15, 23, 42),
        font=f_box_t,
    )
    draw.text(
        (635, 648),
        "scripts/smoke.sh against dev ALB URL -> 401 unauth, 401 wrong key, 200 SSM key, 404 route\ndeleteDir() workspace sanitisation",
        fill=(71, 85, 105),
        font=f_box_d,
    )

    img.save(output_png, "PNG")
    print(f"Generated {output_svg} and {output_png}")


def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(out_dir, exist_ok=True)

    aws_svg = os.path.join(out_dir, "aws-architecture.svg")
    aws_png = os.path.join(out_dir, "aws-architecture.png")
    generate_aws_architecture(aws_svg, aws_png)

    cicd_svg = os.path.join(out_dir, "cicd-flow.svg")
    cicd_png = os.path.join(out_dir, "cicd-flow.png")
    generate_cicd_flow(cicd_svg, cicd_png)


if __name__ == "__main__":
    main()
