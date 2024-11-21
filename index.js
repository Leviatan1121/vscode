const fs = require('fs');
const path = require('path');

const extensionsPath = path.join(__dirname, '.vscode', 'extensions');

const extensions = [];
try {
    const items = fs.readdirSync(extensionsPath);

    items.forEach(item => {
        const itemPath = path.join(extensionsPath, item);
        const extensionJsonPath = path.join(itemPath, 'extensions.json');

        if (fs.statSync(itemPath).isDirectory() && fs.existsSync(extensionJsonPath)) {
            extensions.push(item);
        }
    });

    console.log('Extensiones detectadas:', extensions);
    
    // Crear archivo extensions.json
    const outputPath = path.join(__dirname, 'extensions.json');
    try {
        const jsonContent = JSON.stringify(extensions.map(String), null, 2);
        fs.writeFileSync(outputPath, jsonContent);
        console.log('Archivo extensions.json creado exitosamente');
    } catch (error) {
        console.error('Error al crear extensions.json:', error);
    }
} catch (error) {
    console.error('Error al leer el directorio de extensiones:', error);
}