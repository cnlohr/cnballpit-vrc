#if UNITY_EDITOR
using UnityEngine;
using UnityEditor;

public class CreateMesh : MonoBehaviour
{
    [MenuItem("Tools/CNBallpit Create Mesh")]
    static void CreateMesh_()
    {
        int size = (32 * 32 * 32) / 8;
        Mesh mesh = new Mesh();
        mesh.vertices = new Vector3[1];
        mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(40, 40, 40));
        mesh.SetIndices(new int[size], MeshTopology.Points, 0, false, 0);
        string sizeLabel = size < 1024 ? "" + size : "" + (size / 1024) + "k";
        AssetDatabase.CreateAsset(mesh, "Assets/cnballpit/ball_points.asset");
    }
}
#endif