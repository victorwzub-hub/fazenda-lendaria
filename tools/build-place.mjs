// Gera FazendaLendaria.rbxlx a partir de src/, seguindo as mesmas regras de nomes do Rojo
// (init.server.luau vira Script, init.client.luau vira LocalScript, .luau vira ModuleScript).
// Uso: node tools/build-place.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const project = JSON.parse(fs.readFileSync(path.join(ROOT, 'default.project.json'), 'utf8'));
const OUTPUT = path.join(ROOT, 'FazendaLendaria.rbxlx');

let nextRef = 0;
const ref = () => `RBX${(nextRef++).toString(16).toUpperCase().padStart(8, '0')}`;

const escapeXml = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const cdata = (s) => `<![CDATA[${s.replaceAll(']]>', ']]]]><![CDATA[>')}]]>`;

function item(className, name, children = [], source = null) {
  const props = [`<string name="Name">${escapeXml(name)}</string>`];
  if (source !== null) props.push(`<ProtectedString name="Source">${cdata(source)}</ProtectedString>`);
  return `<Item class="${className}" referent="${ref()}"><Properties>${props.join('')}</Properties>${children.join('')}</Item>`;
}

function scriptClass(fileName) {
  if (fileName.endsWith('.server.luau')) return 'Script';
  if (fileName.endsWith('.client.luau')) return 'LocalScript';
  return 'ModuleScript';
}

function fromPath(name, target) {
  const stat = fs.statSync(target);
  if (stat.isFile()) {
    return item(scriptClass(target), name, [], fs.readFileSync(target, 'utf8'));
  }
  const entries = fs.readdirSync(target).sort();
  const init = entries.find((e) => /^init(\.server|\.client)?\.luau$/.test(e));
  const children = entries
    .filter((e) => e !== init && (e.endsWith('.luau') || fs.statSync(path.join(target, e)).isDirectory()))
    .map((e) => fromPath(e.replace(/(\.server|\.client)?\.luau$/, ''), path.join(target, e)));
  if (init) {
    return item(scriptClass(init), name, children, fs.readFileSync(path.join(target, init), 'utf8'));
  }
  return item('Folder', name, children);
}

function fromNode(name, node) {
  const children = Object.entries(node)
    .filter(([key]) => !key.startsWith('$'))
    .map(([key, child]) => fromNode(key, child));
  if (node.$path) {
    const built = fromPath(name, path.join(ROOT, node.$path));
    return children.length ? built.replace(/<\/Item>$/, `${children.join('')}</Item>`) : built;
  }
  return item(node.$className, name, children);
}

const services = Object.entries(project.tree)
  .filter(([key]) => !key.startsWith('$'))
  .map(([key, node]) => fromNode(key, node));

const xml = `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
<Meta name="ExplicitAutoJoints">true</Meta>
<External>null</External>
<External>nil</External>
${services.join('\n')}
</roblox>
`;

fs.writeFileSync(OUTPUT, xml);
console.log(`Gerado ${path.relative(ROOT, OUTPUT)} (${(xml.length / 1024).toFixed(1)} KB)`);
