import 'dart:convert';
import 'dart:typed_data';

class GlbParser {
  static List<String> extractMeshNames(Uint8List bytes) {
    try {
      if (bytes.length < 20) return [];
      final bd = bytes.buffer.asByteData();
      // GLB magic: 'glTF' = 0x46546C67
      if (bd.getUint32(0, Endian.little) != 0x46546C67) return [];
      // Chunk 0 header at offset 12 (length) and 16 (type)
      final chunkLen = bd.getUint32(12, Endian.little);
      final chunkType = bd.getUint32(16, Endian.little);
      if (chunkType != 0x4E4F534A) return []; // 'JSON'
      if (20 + chunkLen > bytes.length) return [];
      final jsonStr = utf8.decode(bytes.sublist(20, 20 + chunkLen));
      final gltf = jsonDecode(jsonStr) as Map<String, dynamic>;
      final meshes = gltf['meshes'] as List?;
      if (meshes == null || meshes.isEmpty) return [];
      return meshes.asMap().entries.map((e) {
        final m = e.value as Map<String, dynamic>;
        return (m['name'] as String?)?.isNotEmpty == true
            ? m['name'] as String
            : 'Mesh_${e.key}';
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
