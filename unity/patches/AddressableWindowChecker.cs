using NSMedieval.Editor;
using UnityEditor;

namespace NSMedieval.Tools
{
    // Patched (phrontisteries): open the Addressable Builder once per editor session, after the
    // editor has finished loading, and only if no builder window exists. The original opened it from
    // the static constructor on every domain reload, which could leave two builder windows that keep
    // refreshing each other and freeze the editor.
    [InitializeOnLoad]
    public class AddressableWindowChecker
    {
        private const string OpenedKey = "NSMedieval.AddressableBuilder.OpenedThisSession";

        static AddressableWindowChecker()
        {
            if (SessionState.GetBool(OpenedKey, false))
            {
                return;
            }

            EditorApplication.delayCall += () =>
            {
                SessionState.SetBool(OpenedKey, true);
                if (!EditorWindow.HasOpenInstances<AddressableBuilder>())
                {
                    EditorWindow.GetWindow<AddressableBuilder>("Addressable Builder");
                }
            };
        }
    }
}
