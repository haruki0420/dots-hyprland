.pragma library

// Keep only display metadata. Never expose the biometric vectors to delegates.
function metadata(text) {
    const models = JSON.parse(text);
    if (!Array.isArray(models)) throw new Error("Invalid model list");
    return models.map(model => {
        if (!Number.isInteger(model.id) || model.id < 0
            || typeof model.label !== "string" || !Number.isFinite(model.time)
            || model.time <= 0) throw new Error("Invalid model metadata");
        return { id: model.id, label: model.label, time: model.time };
    }).sort((a, b) => b.time - a.time || b.id - a.id);
}

function nextName(models, template) {
    const used = new Set();
    for (const model of models) {
        // Keep numbering consistent when switching between Japanese and English.
        const match = /^(?:顔認証|Face authentication )([1-9][0-9]*)$/.exec(model.label);
        if (match) used.add(Number(match[1]));
    }
    let number = 1;
    while (used.has(number)) number++;
    return template.replace("%1", String(number));
}
