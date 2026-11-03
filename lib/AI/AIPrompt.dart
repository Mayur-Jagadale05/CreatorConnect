/// Class defining suggested quick prompts for UI display
class AIPromptSuggestion {
  final String title;
  final String prompt;
  final String iconCode;

  const AIPromptSuggestion({
    required this.title,
    required this.prompt,
    required this.iconCode,
  });
}

/// System instructions and prompt templates for CreatorConnect AI
class AIPrompt {
  /// Returns tailored system instructions according to user role
  static String getSystemInstruction({
    required String role,
    String? userName,
  }) {
    final cleanRole = role.trim().toLowerCase();
    final greeting = (userName != null && userName.isNotEmpty)
        ? 'The user you are assisting is named $userName.'
        : 'The user is a valued member of CreatorConnect.';

    switch (cleanRole) {
      case 'influencer':
        return '''
You are "CreatorConnect AI" for Influencers — an elite digital strategist and content creation consultant.
$greeting
Your primary areas of expertise:
1. Instagram Reel ideas, hooks, and trend forecasts.
2. YouTube Shorts and viral short-form video strategies.
3. Engaging captions, keyword-optimized SEO, and high-reach hashtag strategies.
4. Content calendars, publishing schedules, and multi-platform planning.
5. Audience growth, retention analytics, and community engagement tactics.
6. Brand collaboration guidance, sponsorship pitch templates, rate calculation, and media kit tips.

Tone & Style:
- Energetic, motivating, creative, and actionable.
- Provide practical scripts, hook frameworks (first 3 seconds), and step-by-step instructions.
- Format with clear bullet points, emojis where appropriate, and highlighted callouts.
''';

      case 'editor':
      case 'video editor':
        return '''
You are "CreatorConnect AI" for Video Editors — a senior post-production supervisor and workflow master.
$greeting
Your primary areas of expertise:
1. Video editing techniques, pacing, rhythm, and narrative structure.
2. Adobe Premiere Pro troubleshooting, keyboard shortcuts, effects, and dynamic link workflows.
3. DaVinci Resolve color grading (nodes, color spaces, LUTs, primaries) and Fusion effects.
4. Transitions, sound design, SFX layering, beat syncing, and visual effects.
5. Export presets for high bitrate and crisp upload quality across Instagram, YouTube, and TikTok.
6. Editor portfolio enhancement, showreel curation, client communication, and freelance pricing.

Tone & Style:
- Technical, precise, professional, and practical.
- Give exact software menus, shortcuts (Windows/Mac), codec recommendations, and workflow steps.
- Avoid vague advice; provide measurable parameters (e.g. dB audio levels, fps, bitrates).
''';

      case 'writer':
        return '''
You are "CreatorConnect AI" for Writers — a world-class copywriter, narrative architect, and script doctor.
$greeting
Your primary areas of expertise:
1. Retention-driven YouTube long-form scripts and 60-second short-form Reel/Shorts scripts.
2. Irresistible hooks, storytelling frameworks (Hero's Journey, Problem-Agitate-Solve, AIDA).
3. Compelling blog ideas, outline architecture, and SEO content writing.
4. High-conversion marketing copywriting, landing page headlines, and newsletter emails.
5. Social media captions, carousel copy, thought-leadership posts, and viral threads.
6. Dialogue polish, tone adjustments, and rhythm optimization.

Tone & Style:
- Eloquent, imaginative, structured, and persuasive.
- Provide read-to-use scripts with [Visual], [Audio], [Hook], and [CTA] tags.
- Offer variation options (e.g. 3 different opening hooks for testing).
''';

      case 'businessman':
        return '''
You are "CreatorConnect AI" for Businesses & Entrepreneurs — a high-impact creative director and talent recruitment strategist.
$greeting
Your primary areas of expertise:
1. Creator recommendations: matching your campaigns with top video editors, writers, and influencers.
2. Comprehensive influencer marketing strategies and campaign roadmap planning.
3. Collaboration briefs, milestone structures, deliverables agreements, and SLA guidance.
4. Budget planning, ROI calculation, cost-per-view benchmarks, and sponsorship negotiation.
5. Influencer vetting, audience demographic checks, and authenticity verification.

CRITICAL CREATOR MATCHING RULES:
- When recommending creators from CreatorConnect, ONLY use the actual verified creator profiles provided in your system context.
- Never invent names, fake handles, imaginary ratings, or fabricated portfolio URLs.
- Highlight candidate skills, location, experience tier, and why they fit the user's specific business objective.
- If no matching creators exist for a specific location or niche in the context, clearly explain this and advise adjusting the criteria.

Tone & Style:
- Strategic, professional, ROI-focused, executive, and decisive.
- Use clear bullet points, executive summaries, and actionable next steps.
''';

      default:
        return '''
You are "CreatorConnect AI" — the intelligent assistant for the CreatorConnect collaborative platform.
$greeting
CreatorConnect unites Influencers, Video Editors, Content Writers, and Businesses to produce exceptional creative work.
Help the user collaborate, brainstorm creative concepts, optimize their workflow, and thrive on the platform.
''';
    }
  }

  /// Returns role-based prompt starter suggestions
  static List<AIPromptSuggestion> getSuggestedPrompts(String role) {
    final cleanRole = role.trim().toLowerCase();

    switch (cleanRole) {
      case 'influencer':
        return const [
          AIPromptSuggestion(
            title: 'Viral Reel Hooks',
            prompt:
                'Give me 5 viral, scroll-stopping hooks for my next Instagram Reel that grab viewer attention in the first 3 seconds.',
            iconCode: 'auto_awesome',
          ),
          AIPromptSuggestion(
            title: 'Brand Pitch Template',
            prompt:
                'Write a high-converting, professional pitch email and DM to propose a paid sponsorship to lifestyle brands.',
            iconCode: 'mail',
          ),
          AIPromptSuggestion(
            title: 'Caption & SEO Hashtags',
            prompt:
                'Write an engaging, storytelling Instagram caption with trending high-reach hashtags for my latest content.',
            iconCode: 'tag',
          ),
          AIPromptSuggestion(
            title: '7-Day Content Plan',
            prompt:
                'Create a 7-day content schedule balancing educational tips, entertaining Reels, and interactive engagement ideas.',
            iconCode: 'calendar_month',
          ),
          AIPromptSuggestion(
            title: 'Find Expert Editor',
            prompt:
                'Recommend top-rated video editors on CreatorConnect who can edit high-retention Reels, Shorts, and YouTube videos.',
            iconCode: 'person_search',
          ),
        ];

      case 'editor':
      case 'video editor':
        return const [
          AIPromptSuggestion(
            title: 'Retention Editing Tricks',
            prompt:
                'What are the top visual pacing, SFX layering, and transition techniques to keep viewers hooked till the very last second?',
            iconCode: 'speed',
          ),
          AIPromptSuggestion(
            title: 'Client Pitch Message',
            prompt:
                'Write a persuasive outreach message to pitch my video editing services to YouTubers, creators, and brands.',
            iconCode: 'mail',
          ),
          AIPromptSuggestion(
            title: 'Best Export Settings',
            prompt:
                'What are the best export settings in Premiere Pro / DaVinci Resolve for ultra-crisp Instagram Reels and YouTube videos?',
            iconCode: 'file_download',
          ),
          AIPromptSuggestion(
            title: 'Freelance Rate Calculator',
            prompt:
                'How should I price my short-form Reels and long-form video editing packages for creators and businesses?',
            iconCode: 'account_balance_wallet',
          ),
          AIPromptSuggestion(
            title: 'Winning Showreel Guide',
            prompt:
                'How should I structure a 45-second video editing showreel that convinces high-paying clients to hire me immediately?',
            iconCode: 'movie_filter',
          ),
        ];

      case 'writer':
        return const [
          AIPromptSuggestion(
            title: '60s Viral Video Script',
            prompt:
                'Write a high-energy 60-second video script with visual cues, a psychological hook, value delivery, and a strong CTA.',
            iconCode: 'description',
          ),
          AIPromptSuggestion(
            title: 'Psychological Hooks',
            prompt:
                'Give me 5 irresistible psychological hook templates (Curiosity gap, Contrarian, FOMO) for my next post or video.',
            iconCode: 'lightbulb',
          ),
          AIPromptSuggestion(
            title: 'Ad Copywriting (AIDA)',
            prompt:
                'Write persuasive ad copywriting using the AIDA (Attention, Interest, Desire, Action) framework to promote a product.',
            iconCode: 'campaign',
          ),
          AIPromptSuggestion(
            title: 'YouTube Script Outline',
            prompt:
                'Create an engaging outline for an 8-minute YouTube video with storytelling arcs, chapter retention hooks, and CTA.',
            iconCode: 'edit_note',
          ),
          AIPromptSuggestion(
            title: 'Writer Outreach Pitch',
            prompt:
                'Write a professional pitch offering scriptwriting and content copywriting services to busy influencers and brands.',
            iconCode: 'mail',
          ),
        ];

      case 'businessman':
        return const [
          AIPromptSuggestion(
            title: 'Find Top Video Editors',
            prompt:
                'Recommend experienced video editors on CreatorConnect for commercial brand ads, product videos, and viral Reels.',
            iconCode: 'person_search',
          ),
          AIPromptSuggestion(
            title: 'Find Brand Influencers',
            prompt:
                'Help me find top influencers on CreatorConnect with genuine audience engagement for our brand promotion.',
            iconCode: 'stars',
          ),
          AIPromptSuggestion(
            title: 'Hire Script & Ad Writers',
            prompt:
                'Find skilled copywriters and video scriptwriters on CreatorConnect to craft high-converting business marketing campaigns.',
            iconCode: 'assignment',
          ),
          AIPromptSuggestion(
            title: 'Campaign Budget & ROI',
            prompt:
                'How should I plan and allocate our creator collaboration budget between micro and macro creators for maximum ROI?',
            iconCode: 'account_balance_wallet',
          ),
          AIPromptSuggestion(
            title: 'Creative Brief Template',
            prompt:
                'Draft a clear creative brief and deliverables agreement template for hiring freelance creators and editors.',
            iconCode: 'description',
          ),
        ];

      default:
        return const [
          AIPromptSuggestion(
            title: 'Find Verified Creators',
            prompt:
                'Who are the top-rated verified creators, editors, and writers available for collaboration on CreatorConnect right now?',
            iconCode: 'person_search',
          ),
          AIPromptSuggestion(
            title: 'How to Collaborate',
            prompt:
                'How does connecting, sharing videos, sending messages, and collaborating work on CreatorConnect?',
            iconCode: 'handshake',
          ),
          AIPromptSuggestion(
            title: 'Grow Your Career',
            prompt:
                'What are the best strategies to get noticed, build strong creator connections, and land projects on CreatorConnect?',
            iconCode: 'auto_awesome',
          ),
          AIPromptSuggestion(
            title: 'Brainstorm Viral Ideas',
            prompt:
                'Help me brainstorm 5 unique and trending content concepts for my creative niche this week.',
            iconCode: 'lightbulb',
          ),
        ];
    }
  }
}

