//
//  DomainSuggestionDatabase.swift
//  TunnelMaster
//
//  Provides domain suggestions organized by category for the rule builder.
//

import Foundation

/// A domain suggestion entry
struct DomainSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let domain: String
    let name: String
    let icon: String

    init(domain: String, name: String, icon: String) {
        self.id = domain
        self.domain = domain
        self.name = name
        self.icon = icon
    }
}

/// Category for domain suggestions
struct DomainCategory: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let icon: String
    let domains: [DomainSuggestion]

    var domainCount: Int {
        domains.count
    }
}

/// Database of popular domains organized by category
enum DomainSuggestionDatabase {
    // MARK: - Categories

    static let categories: [DomainCategory] = [
        streaming,
        social,
        productivity,
        gaming,
        shopping,
        development,
        cloud,
        ai,
        news,
        finance
    ]

    // MARK: - Streaming

    static let streaming = DomainCategory(
        id: "streaming",
        name: "Streaming",
        icon: "play.tv",
        domains: [
            DomainSuggestion(domain: "netflix.com", name: "Netflix", icon: "play.rectangle"),
            DomainSuggestion(domain: "youtube.com", name: "YouTube", icon: "play.rectangle"),
            DomainSuggestion(domain: "disneyplus.com", name: "Disney+", icon: "play.rectangle"),
            DomainSuggestion(domain: "hbomax.com", name: "HBO Max", icon: "play.rectangle"),
            DomainSuggestion(domain: "max.com", name: "Max", icon: "play.rectangle"),
            DomainSuggestion(domain: "hulu.com", name: "Hulu", icon: "play.rectangle"),
            DomainSuggestion(domain: "primevideo.com", name: "Prime Video", icon: "play.rectangle"),
            DomainSuggestion(domain: "twitch.tv", name: "Twitch", icon: "play.rectangle"),
            DomainSuggestion(domain: "spotify.com", name: "Spotify", icon: "music.note"),
            DomainSuggestion(domain: "apple.com/apple-tv", name: "Apple TV+", icon: "play.rectangle"),
            DomainSuggestion(domain: "peacocktv.com", name: "Peacock", icon: "play.rectangle"),
            DomainSuggestion(domain: "paramountplus.com", name: "Paramount+", icon: "play.rectangle"),
            DomainSuggestion(domain: "crunchyroll.com", name: "Crunchyroll", icon: "play.rectangle"),
            DomainSuggestion(domain: "dazn.com", name: "DAZN", icon: "play.rectangle")
        ]
    )

    // MARK: - Social Media

    static let social = DomainCategory(
        id: "social",
        name: "Social Media",
        icon: "person.2",
        domains: [
            DomainSuggestion(domain: "facebook.com", name: "Facebook", icon: "person.2"),
            DomainSuggestion(domain: "instagram.com", name: "Instagram", icon: "camera"),
            DomainSuggestion(domain: "twitter.com", name: "Twitter/X", icon: "at"),
            DomainSuggestion(domain: "x.com", name: "X", icon: "at"),
            DomainSuggestion(domain: "tiktok.com", name: "TikTok", icon: "music.note"),
            DomainSuggestion(domain: "reddit.com", name: "Reddit", icon: "text.bubble"),
            DomainSuggestion(domain: "linkedin.com", name: "LinkedIn", icon: "briefcase"),
            DomainSuggestion(domain: "pinterest.com", name: "Pinterest", icon: "pin"),
            DomainSuggestion(domain: "snapchat.com", name: "Snapchat", icon: "camera"),
            DomainSuggestion(domain: "threads.net", name: "Threads", icon: "at"),
            DomainSuggestion(domain: "mastodon.social", name: "Mastodon", icon: "at"),
            DomainSuggestion(domain: "bsky.app", name: "Bluesky", icon: "at")
        ]
    )

    // MARK: - Messaging

    static let messaging = DomainCategory(
        id: "messaging",
        name: "Messaging",
        icon: "message",
        domains: [
            DomainSuggestion(domain: "telegram.org", name: "Telegram", icon: "message"),
            DomainSuggestion(domain: "whatsapp.com", name: "WhatsApp", icon: "message"),
            DomainSuggestion(domain: "signal.org", name: "Signal", icon: "message"),
            DomainSuggestion(domain: "discord.com", name: "Discord", icon: "message"),
            DomainSuggestion(domain: "slack.com", name: "Slack", icon: "message"),
            DomainSuggestion(domain: "messenger.com", name: "Messenger", icon: "message")
        ]
    )

    // MARK: - Productivity

    static let productivity = DomainCategory(
        id: "productivity",
        name: "Productivity",
        icon: "doc.text",
        domains: [
            DomainSuggestion(domain: "google.com", name: "Google", icon: "magnifyingglass"),
            DomainSuggestion(domain: "drive.google.com", name: "Google Drive", icon: "folder"),
            DomainSuggestion(domain: "docs.google.com", name: "Google Docs", icon: "doc.text"),
            DomainSuggestion(domain: "notion.so", name: "Notion", icon: "doc.text"),
            DomainSuggestion(domain: "dropbox.com", name: "Dropbox", icon: "folder"),
            DomainSuggestion(domain: "evernote.com", name: "Evernote", icon: "note.text"),
            DomainSuggestion(domain: "trello.com", name: "Trello", icon: "list.bullet.rectangle"),
            DomainSuggestion(domain: "asana.com", name: "Asana", icon: "checklist"),
            DomainSuggestion(domain: "monday.com", name: "Monday.com", icon: "checklist"),
            DomainSuggestion(domain: "airtable.com", name: "Airtable", icon: "tablecells"),
            DomainSuggestion(domain: "figma.com", name: "Figma", icon: "paintbrush"),
            DomainSuggestion(domain: "miro.com", name: "Miro", icon: "rectangle.3.group"),
            DomainSuggestion(domain: "zoom.us", name: "Zoom", icon: "video"),
            DomainSuggestion(domain: "teams.microsoft.com", name: "Microsoft Teams", icon: "video")
        ]
    )

    // MARK: - Gaming

    static let gaming = DomainCategory(
        id: "gaming",
        name: "Gaming",
        icon: "gamecontroller",
        domains: [
            DomainSuggestion(domain: "steampowered.com", name: "Steam", icon: "gamecontroller"),
            DomainSuggestion(domain: "epicgames.com", name: "Epic Games", icon: "gamecontroller"),
            DomainSuggestion(domain: "gog.com", name: "GOG", icon: "gamecontroller"),
            DomainSuggestion(domain: "blizzard.com", name: "Blizzard", icon: "gamecontroller"),
            DomainSuggestion(domain: "battle.net", name: "Battle.net", icon: "gamecontroller"),
            DomainSuggestion(domain: "ea.com", name: "EA", icon: "gamecontroller"),
            DomainSuggestion(domain: "origin.com", name: "Origin", icon: "gamecontroller"),
            DomainSuggestion(domain: "ubisoft.com", name: "Ubisoft", icon: "gamecontroller"),
            DomainSuggestion(domain: "riotgames.com", name: "Riot Games", icon: "gamecontroller"),
            DomainSuggestion(domain: "playstation.com", name: "PlayStation", icon: "gamecontroller"),
            DomainSuggestion(domain: "xbox.com", name: "Xbox", icon: "gamecontroller"),
            DomainSuggestion(domain: "nintendo.com", name: "Nintendo", icon: "gamecontroller")
        ]
    )

    // MARK: - Shopping

    static let shopping = DomainCategory(
        id: "shopping",
        name: "Shopping",
        icon: "cart",
        domains: [
            DomainSuggestion(domain: "amazon.com", name: "Amazon", icon: "cart"),
            DomainSuggestion(domain: "ebay.com", name: "eBay", icon: "cart"),
            DomainSuggestion(domain: "walmart.com", name: "Walmart", icon: "cart"),
            DomainSuggestion(domain: "target.com", name: "Target", icon: "cart"),
            DomainSuggestion(domain: "bestbuy.com", name: "Best Buy", icon: "cart"),
            DomainSuggestion(domain: "aliexpress.com", name: "AliExpress", icon: "cart"),
            DomainSuggestion(domain: "etsy.com", name: "Etsy", icon: "cart"),
            DomainSuggestion(domain: "newegg.com", name: "Newegg", icon: "cart")
        ]
    )

    // MARK: - Development

    static let development = DomainCategory(
        id: "development",
        name: "Development",
        icon: "chevron.left.forwardslash.chevron.right",
        domains: [
            DomainSuggestion(domain: "github.com", name: "GitHub", icon: "chevron.left.forwardslash.chevron.right"),
            DomainSuggestion(domain: "gitlab.com", name: "GitLab", icon: "chevron.left.forwardslash.chevron.right"),
            DomainSuggestion(domain: "bitbucket.org", name: "Bitbucket", icon: "chevron.left.forwardslash.chevron.right"),
            DomainSuggestion(domain: "stackoverflow.com", name: "Stack Overflow", icon: "questionmark.circle"),
            DomainSuggestion(domain: "npmjs.com", name: "npm", icon: "shippingbox"),
            DomainSuggestion(domain: "pypi.org", name: "PyPI", icon: "shippingbox"),
            DomainSuggestion(domain: "crates.io", name: "crates.io", icon: "shippingbox"),
            DomainSuggestion(domain: "hub.docker.com", name: "Docker Hub", icon: "shippingbox"),
            DomainSuggestion(domain: "vercel.com", name: "Vercel", icon: "cloud"),
            DomainSuggestion(domain: "netlify.com", name: "Netlify", icon: "cloud"),
            DomainSuggestion(domain: "heroku.com", name: "Heroku", icon: "cloud"),
            DomainSuggestion(domain: "railway.app", name: "Railway", icon: "cloud")
        ]
    )

    // MARK: - Cloud Services

    static let cloud = DomainCategory(
        id: "cloud",
        name: "Cloud Services",
        icon: "cloud",
        domains: [
            DomainSuggestion(domain: "aws.amazon.com", name: "AWS", icon: "cloud"),
            DomainSuggestion(domain: "cloud.google.com", name: "Google Cloud", icon: "cloud"),
            DomainSuggestion(domain: "azure.microsoft.com", name: "Azure", icon: "cloud"),
            DomainSuggestion(domain: "digitalocean.com", name: "DigitalOcean", icon: "cloud"),
            DomainSuggestion(domain: "linode.com", name: "Linode", icon: "cloud"),
            DomainSuggestion(domain: "vultr.com", name: "Vultr", icon: "cloud"),
            DomainSuggestion(domain: "cloudflare.com", name: "Cloudflare", icon: "cloud"),
            DomainSuggestion(domain: "hetzner.com", name: "Hetzner", icon: "cloud")
        ]
    )

    // MARK: - AI Services

    static let ai = DomainCategory(
        id: "ai",
        name: "AI Services",
        icon: "brain",
        domains: [
            DomainSuggestion(domain: "openai.com", name: "OpenAI", icon: "brain"),
            DomainSuggestion(domain: "chat.openai.com", name: "ChatGPT", icon: "brain"),
            DomainSuggestion(domain: "anthropic.com", name: "Anthropic", icon: "brain"),
            DomainSuggestion(domain: "claude.ai", name: "Claude", icon: "brain"),
            DomainSuggestion(domain: "bard.google.com", name: "Bard", icon: "brain"),
            DomainSuggestion(domain: "gemini.google.com", name: "Gemini", icon: "brain"),
            DomainSuggestion(domain: "midjourney.com", name: "Midjourney", icon: "paintbrush"),
            DomainSuggestion(domain: "stability.ai", name: "Stability AI", icon: "paintbrush"),
            DomainSuggestion(domain: "huggingface.co", name: "Hugging Face", icon: "brain"),
            DomainSuggestion(domain: "perplexity.ai", name: "Perplexity", icon: "magnifyingglass")
        ]
    )

    // MARK: - News & Media

    static let news = DomainCategory(
        id: "news",
        name: "News & Media",
        icon: "newspaper",
        domains: [
            DomainSuggestion(domain: "nytimes.com", name: "NY Times", icon: "newspaper"),
            DomainSuggestion(domain: "washingtonpost.com", name: "Washington Post", icon: "newspaper"),
            DomainSuggestion(domain: "bbc.com", name: "BBC", icon: "newspaper"),
            DomainSuggestion(domain: "cnn.com", name: "CNN", icon: "newspaper"),
            DomainSuggestion(domain: "theguardian.com", name: "The Guardian", icon: "newspaper"),
            DomainSuggestion(domain: "reuters.com", name: "Reuters", icon: "newspaper"),
            DomainSuggestion(domain: "apnews.com", name: "AP News", icon: "newspaper"),
            DomainSuggestion(domain: "medium.com", name: "Medium", icon: "doc.text"),
            DomainSuggestion(domain: "substack.com", name: "Substack", icon: "envelope")
        ]
    )

    // MARK: - Finance

    static let finance = DomainCategory(
        id: "finance",
        name: "Finance",
        icon: "dollarsign.circle",
        domains: [
            DomainSuggestion(domain: "paypal.com", name: "PayPal", icon: "creditcard"),
            DomainSuggestion(domain: "stripe.com", name: "Stripe", icon: "creditcard"),
            DomainSuggestion(domain: "coinbase.com", name: "Coinbase", icon: "bitcoinsign.circle"),
            DomainSuggestion(domain: "binance.com", name: "Binance", icon: "bitcoinsign.circle"),
            DomainSuggestion(domain: "kraken.com", name: "Kraken", icon: "bitcoinsign.circle"),
            DomainSuggestion(domain: "robinhood.com", name: "Robinhood", icon: "chart.line.uptrend.xyaxis"),
            DomainSuggestion(domain: "schwab.com", name: "Schwab", icon: "chart.line.uptrend.xyaxis"),
            DomainSuggestion(domain: "fidelity.com", name: "Fidelity", icon: "chart.line.uptrend.xyaxis")
        ]
    )

    // MARK: - Search

    /// Search all domains across categories
    static func search(_ query: String) -> [DomainSuggestion] {
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()

        return categories.flatMap(\.domains).filter {
            $0.domain.lowercased().contains(lowercased) ||
                $0.name.lowercased().contains(lowercased)
        }
    }

    /// Get all domains as a flat list
    static var allDomains: [DomainSuggestion] {
        categories.flatMap(\.domains)
    }
}

// MARK: - GeoSite Categories

/// Popular GeoSite categories from sing-box geosite database
enum GeoSiteDatabase {
    struct GeoSiteCategory: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let description: String
        let icon: String
    }

    static let categories: [GeoSiteCategory] = [
        // Countries
        GeoSiteCategory(id: "cn", name: "China", description: "Chinese websites and services", icon: "flag"),
        GeoSiteCategory(id: "ru", name: "Russia", description: "Russian websites and services", icon: "flag"),
        GeoSiteCategory(id: "ir", name: "Iran", description: "Iranian websites and services", icon: "flag"),

        // Services
        GeoSiteCategory(id: "google", name: "Google", description: "All Google services", icon: "magnifyingglass"),
        GeoSiteCategory(id: "facebook", name: "Facebook/Meta", description: "Facebook, Instagram, WhatsApp", icon: "person.2"),
        GeoSiteCategory(id: "twitter", name: "Twitter/X", description: "Twitter and related services", icon: "at"),
        GeoSiteCategory(id: "telegram", name: "Telegram", description: "Telegram messaging", icon: "message"),
        GeoSiteCategory(id: "youtube", name: "YouTube", description: "YouTube and related services", icon: "play.rectangle"),
        GeoSiteCategory(id: "netflix", name: "Netflix", description: "Netflix streaming", icon: "play.rectangle"),
        GeoSiteCategory(id: "disney", name: "Disney", description: "Disney+ and related", icon: "play.rectangle"),
        GeoSiteCategory(id: "hbo", name: "HBO", description: "HBO Max/Max streaming", icon: "play.rectangle"),
        GeoSiteCategory(id: "spotify", name: "Spotify", description: "Spotify music", icon: "music.note"),
        GeoSiteCategory(id: "tiktok", name: "TikTok", description: "TikTok and ByteDance", icon: "music.note"),
        GeoSiteCategory(id: "instagram", name: "Instagram", description: "Instagram", icon: "camera"),
        GeoSiteCategory(id: "github", name: "GitHub", description: "GitHub and related", icon: "chevron.left.forwardslash.chevron.right"),
        GeoSiteCategory(id: "microsoft", name: "Microsoft", description: "Microsoft services", icon: "desktopcomputer"),
        GeoSiteCategory(id: "apple", name: "Apple", description: "Apple services", icon: "apple.logo"),
        GeoSiteCategory(id: "amazon", name: "Amazon", description: "Amazon services", icon: "cart"),
        GeoSiteCategory(id: "openai", name: "OpenAI", description: "ChatGPT and OpenAI", icon: "brain"),

        // Categories
        GeoSiteCategory(id: "category-ads", name: "Ads", description: "Advertisement domains", icon: "nosign"),
        GeoSiteCategory(id: "category-ads-all", name: "Ads (Extended)", description: "Extended ad blocking", icon: "nosign"),
        GeoSiteCategory(id: "category-porn", name: "Adult Content", description: "Adult websites", icon: "exclamationmark.triangle"),
        GeoSiteCategory(id: "category-gambling", name: "Gambling", description: "Gambling websites", icon: "dice"),

        // Gaming
        GeoSiteCategory(id: "steam", name: "Steam", description: "Steam gaming platform", icon: "gamecontroller"),
        GeoSiteCategory(id: "epicgames", name: "Epic Games", description: "Epic Games Store", icon: "gamecontroller"),
        GeoSiteCategory(id: "blizzard", name: "Blizzard", description: "Blizzard games", icon: "gamecontroller"),
        GeoSiteCategory(id: "ea", name: "EA", description: "Electronic Arts", icon: "gamecontroller")
    ]

    static func search(_ query: String) -> [GeoSiteCategory] {
        guard !query.isEmpty else { return categories }
        let lowercased = query.lowercased()
        return categories.filter {
            $0.id.lowercased().contains(lowercased) ||
                $0.name.lowercased().contains(lowercased) ||
                $0.description.lowercased().contains(lowercased)
        }
    }
}

// MARK: - IP Presets

/// Common IP range presets
enum IPRangePresets {
    struct IPPreset: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
        let description: String
        let cidr: String
        let icon: String
    }

    static let presets: [IPPreset] = [
        // Private Networks (RFC 1918)
        IPPreset(
            id: "private-a",
            name: "Private Class A",
            description: "10.0.0.0/8 (Large private networks)",
            cidr: "10.0.0.0/8",
            icon: "network"
        ),
        IPPreset(
            id: "private-b",
            name: "Private Class B",
            description: "172.16.0.0/12 (Medium private networks)",
            cidr: "172.16.0.0/12",
            icon: "network"
        ),
        IPPreset(
            id: "private-c",
            name: "Private Class C",
            description: "192.168.0.0/16 (Home/small networks)",
            cidr: "192.168.0.0/16",
            icon: "network"
        ),

        // Special Purpose
        IPPreset(
            id: "loopback",
            name: "Loopback",
            description: "127.0.0.0/8 (localhost)",
            cidr: "127.0.0.0/8",
            icon: "arrow.uturn.backward"
        ),
        IPPreset(
            id: "link-local",
            name: "Link-Local",
            description: "169.254.0.0/16 (Auto-configuration)",
            cidr: "169.254.0.0/16",
            icon: "link"
        ),
        IPPreset(
            id: "docker",
            name: "Docker Default",
            description: "172.17.0.0/16 (Docker containers)",
            cidr: "172.17.0.0/16",
            icon: "shippingbox"
        ),

        // CGNAT
        IPPreset(id: "cgnat", name: "CGNAT", description: "100.64.0.0/10 (Carrier-grade NAT)", cidr: "100.64.0.0/10", icon: "building.2"),

        // Multicast
        IPPreset(id: "multicast", name: "Multicast", description: "224.0.0.0/4 (Multicast addresses)", cidr: "224.0.0.0/4", icon: "wifi")
    ]
}

// MARK: - Country Codes

/// Common country codes for GeoIP rules
enum CountryCodeDatabase {
    struct Country: Identifiable, Hashable, Sendable {
        let code: String
        let name: String
        let flag: String

        var id: String {
            code
        }
    }

    static let countries: [Country] = [
        Country(code: "US", name: "United States", flag: "🇺🇸"),
        Country(code: "GB", name: "United Kingdom", flag: "🇬🇧"),
        Country(code: "CA", name: "Canada", flag: "🇨🇦"),
        Country(code: "AU", name: "Australia", flag: "🇦🇺"),
        Country(code: "DE", name: "Germany", flag: "🇩🇪"),
        Country(code: "FR", name: "France", flag: "🇫🇷"),
        Country(code: "JP", name: "Japan", flag: "🇯🇵"),
        Country(code: "KR", name: "South Korea", flag: "🇰🇷"),
        Country(code: "SG", name: "Singapore", flag: "🇸🇬"),
        Country(code: "HK", name: "Hong Kong", flag: "🇭🇰"),
        Country(code: "TW", name: "Taiwan", flag: "🇹🇼"),
        Country(code: "CN", name: "China", flag: "🇨🇳"),
        Country(code: "RU", name: "Russia", flag: "🇷🇺"),
        Country(code: "IN", name: "India", flag: "🇮🇳"),
        Country(code: "BR", name: "Brazil", flag: "🇧🇷"),
        Country(code: "NL", name: "Netherlands", flag: "🇳🇱"),
        Country(code: "SE", name: "Sweden", flag: "🇸🇪"),
        Country(code: "CH", name: "Switzerland", flag: "🇨🇭"),
        Country(code: "IT", name: "Italy", flag: "🇮🇹"),
        Country(code: "ES", name: "Spain", flag: "🇪🇸"),
        Country(code: "MX", name: "Mexico", flag: "🇲🇽"),
        Country(code: "AR", name: "Argentina", flag: "🇦🇷"),
        Country(code: "PL", name: "Poland", flag: "🇵🇱"),
        Country(code: "TR", name: "Turkey", flag: "🇹🇷"),
        Country(code: "UA", name: "Ukraine", flag: "🇺🇦"),
        Country(code: "IR", name: "Iran", flag: "🇮🇷"),
        Country(code: "AE", name: "UAE", flag: "🇦🇪"),
        Country(code: "SA", name: "Saudi Arabia", flag: "🇸🇦"),
        Country(code: "IL", name: "Israel", flag: "🇮🇱"),
        Country(code: "ZA", name: "South Africa", flag: "🇿🇦")
    ]

    static func search(_ query: String) -> [Country] {
        guard !query.isEmpty else { return countries }
        let lowercased = query.lowercased()
        return countries.filter {
            $0.code.lowercased().contains(lowercased) ||
                $0.name.lowercased().contains(lowercased)
        }
    }
}
