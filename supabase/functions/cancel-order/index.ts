import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Deno runtime global (for TypeScript type checking)
// This declaration has no effect at runtime on Supabase Edge Functions.
declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonError("Unauthorized", 401);

    // Validate caller token and role (store_owner only)
    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (authError || !user) return jsonError("Unauthorized", 401);

    const { data: userProfile } = await supabase
      .from("users")
      .select("role")
      .eq("id", user.id)
      .single();

    if (!userProfile || userProfile.role !== "store_owner") {
      return jsonError("Forbidden: store owners only", 403);
    }

    const { order_id } = await req.json();
    if (!order_id) return jsonError("Missing order_id", 400);

    const { data: store } = await supabase
      .from("stores")
      .select("id")
      .eq("owner_id", user.id)
      .single();

    if (!store) return jsonError("Store not found for this owner", 404);

    const { data: order } = await supabase
      .from("orders")
      .select("id, status, store_id")
      .eq("id", order_id)
      .eq("store_id", store.id)
      .maybeSingle();

    if (!order) {
      return jsonError("Order not found or does not belong to your store", 404);
    }

    // Only allow cancelling orders that are already completed ("confirmed")
    if (order.status !== "confirmed") {
      return new Response(
        JSON.stringify({
          error: `Cannot cancel order. Current status: ${order.status}`,
          current_status: order.status,
        }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { error: updateError } = await supabase
      .from("orders")
      .update({ status: "cancelled" })
      .eq("id", order_id);

    if (updateError) return jsonError("Failed to cancel order", 500);

    return new Response(
      JSON.stringify({ success: true, order_id, status: "cancelled" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("cancel-order error:", err);
    return jsonError("Internal server error", 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

