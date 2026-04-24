import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/model3d.dart';

class Model3DService {
  static final _db = Supabase.instance.client;
  static final _storage = Supabase.instance.client.storage;

  static const _bucket = 'models_3d';
  static const _table = 'project_models';

  static Future<String> uploadGlb(
    String projectId,
    Uint8List bytes,
    String fileName,
  ) async {
    final path = '$projectId/$fileName';
    await _storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'model/gltf-binary',
      ),
    );
    return _storage.from(_bucket).getPublicUrl(path);
  }

  static Future<Model3D?> getModel(String projectId) async {
    final data = await _db
        .from(_table)
        .select()
        .eq('project_id', projectId)
        .maybeSingle();
    if (data == null) return null;
    return Model3D.fromJson(data as Map<String, dynamic>);
  }

  static Future<Model3D> saveModel(
    String projectId,
    String url,
    List<String> meshNames,
  ) async {
    final existing = await _db
        .from(_table)
        .select('id')
        .eq('project_id', projectId)
        .maybeSingle();

    if (existing != null) {
      await _db.from(_table).update({
        'url': url,
        'mesh_names': meshNames,
      }).eq('project_id', projectId);
      return Model3D(
        id: existing['id'].toString(),
        projectId: projectId,
        url: url,
        meshNames: meshNames,
      );
    } else {
      final data = await _db
          .from(_table)
          .insert({'project_id': projectId, 'url': url, 'mesh_names': meshNames})
          .select()
          .single();
      return Model3D.fromJson(data as Map<String, dynamic>);
    }
  }

  static Future<void> deleteModel(String projectId) async {
    await _db.from(_table).delete().eq('project_id', projectId);
  }
}
