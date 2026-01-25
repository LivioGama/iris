import Hero from "@/components/Hero";
import MacStudioAnimation from "@/components/MacStudioAnimation";
import Section from "@/components/Section";

export default function Home() {
  return (
    <main className="bg-[#03040B] min-h-screen text-white pb-32">
      <Hero />
      
      {/* The Scroll Interaction Demo */}
      <MacStudioAnimation />

      <Section 
        title="How I built it" 
        items={[
            {
                subtitle: "Core Architecture",
                text: "I.R.I.S. is architected as a modular reactive system:",
                bullets: [
                    "IRIS Core — orchestrates events, intentions, and reaction rules",
                    "IRIS Vision — analyzes gaze patterns, focus time, and visual context",
                    "IRIS Prompt/Reasoning — generates actions using LLMs only when necessary",
                    "IRIS Spatial (future) — extends to full environment interaction"
                ]
            },
            {
                subtitle: "Technology Stack",
                text: "The LLM serves the detected intention—it's a tool, not the center of the system.",
                bullets: [
                    "Eye tracking for gaze detection and region-of-interest identification",
                    "Voice input for natural language commands and confirmations",
                    "Gemini 2.0 Flash for multimodal understanding and reasoning",
                    "Application context awareness for semantic understanding"
                ]
            }
        ]}
      />

      <Section 
        title="Challenges we ran into" 
        items={[
            {
                subtitle: "Technical Challenges",
                bullets: [
                    "Real-time gaze tracking with sufficient precision",
                    "Inferring intention from attention patterns without explicit prompts",
                    "Balancing responsiveness with computational efficiency",
                    "Designing UI that's invisible yet discoverable"
                ],
                text: ""
            },
            {
                subtitle: "Paradigm Challenges",
                bullets: [
                    "Moving from 'prompt-first' to 'attention-first' interaction",
                    "Creating a system that reacts without being intrusive",
                    "Defining ethical boundaries for attention tracking and memory"
                ],
                text: ""
            },
            {
                subtitle: "Design Challenges",
                bullets: [
                    "Each use case demanded unique UI and logic—human intention isn't a finite menu",
                    "Building for continuous evolution rather than fixed features"
                ],
                text: ""
            }
        ]}
      />

      <Section 
        title="Accomplishments that we're proud of" 
        items={[
            {
                text: [
                    "Paradigm shift: Moving beyond chatbots to truly reactive, multimodal interaction",
                    "Modular architecture: Each component can evolve independently",
                    "Invisible interface: Designed to be ambient rather than intrusive",
                    "Infinite evolution potential: Built to infer intention in any situation, not just predefined scenarios"
                ]
            }
        ]}
      />

      <Section 
        title="What I learned" 
        items={[
            {
                text: "",
                bullets: [
                    "Gaze combined with visual context creates a powerful new dimension for speech-to-text accuracy",
                    "The technology demands careful ethical consideration",
                    "True innovation isn't incremental features—it's changing how we think about computers"
                ]
            }
        ]}
      />

      <Section 
        title="What's next for I.R.I.S." 
        items={[
            {
                subtitle: "Near term",
                bullets: [
                    "Expand scenario coverage based on real user behavior patterns",
                    "Develop attention-indexed memory with privacy controls",
                    "Refine intention inference across diverse content types"
                ],
                text: ""
            },
            {
                subtitle: "Long term",
                bullets: [
                    "Full spatial computing integration for AR/VR environments",
                    "Attention-based information retrieval—find anything you've seen by describing it",
                    "Research platform for next-generation human-AI interaction"
                ],
                text: ""
            },
            {
                subtitle: "The Vision",
                text: "I.R.I.S. isn't trying to be another assistant. It's trying to change how we interact with computers—from typing to true interaction, from apps to ambient intelligence, from GUI to attention-driven interfaces. From gaze to intention to action."
            }
        ]}
      />

      {/* Built With Footer */}
      <footer className="max-w-5xl mx-auto px-8 py-12 border-t border-white/10">
        <h3 className="text-2xl font-bold mb-8 text-white">Built With</h3>
        <div className="flex flex-wrap gap-4">
            {["OpenCV", "Python", "PyTorch", "Rust", "Swift", "TensorFlow"].map((tech) => (
                <span key={tech} className="px-4 py-2 bg-white/5 rounded-full text-gray-300 border border-white/10 text-sm font-medium">
                    {tech}
                </span>
            ))}
        </div>
        <div className="mt-12 text-center text-gray-600 text-sm">
            © 2026 I.R.I.S. Project
        </div>
      </footer>
    </main>
  );
}
