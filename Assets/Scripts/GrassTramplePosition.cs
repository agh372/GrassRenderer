using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class GrassTramplePosition : MonoBehaviour {
    public Material material;
    public float radius;
    public float heightOffset;
    private Renderer renderer;

    private void Start()
    {
        
    }

    void Update() {
        material?.SetVector("_GrassTrample", new Vector4(transform.position.x, transform.position.y + renderer.bounds.extents.magnitude, transform.position.z, renderer.bounds.extents.magnitude));
    }
}