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
