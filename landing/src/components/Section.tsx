export default function Section({ title, items }: { title: string, items: { subtitle?: string, text: string | string[], bullets?: string[] }[] }) {
  return (
    <section className="py-24 px-8 max-w-5xl mx-auto">
      <h2 className="text-4xl md:text-5xl font-bold mb-16 text-white border-l-4 border-[var(--color-brand-purple)] pl-6">
        {title}
      </h2>
      
      <div className="space-y-16">
        {items.map((item, idx) => (
            <div key={idx} className="grid md:grid-cols-[1fr_2fr] gap-8">
                <div className="text-xl font-semibold text-[var(--color-brand-cyan)]">
                    {item.subtitle}
                </div>
                <div className="space-y-4 text-gray-300 text-lg leading-relaxed">
                    {Array.isArray(item.text) ? item.text.map((t, i) => <p key={i}>{t}</p>) : <p>{item.text}</p>}
                    {item.bullets && (
                        <ul className="list-disc list-outside ml-5 space-y-2 mt-4 text-gray-400">
                            {item.bullets.map((b, i) => (
                                <li key={i}>{b}</li>
                            ))}
                        </ul>
                    )}
                </div>
            </div>
        ))}
      </div>
    </section>
  );
}
