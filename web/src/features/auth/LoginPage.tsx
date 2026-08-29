import { AlertTriangle, Loader2, Radio } from "lucide-react";
import { useState, type FormEvent } from "react";
import { useLocation, useNavigate, type Location } from "react-router-dom";
import { ApiError, NetworkError } from "../../lib/api/client";
import { useAuth } from "./useAuth";

interface RedirectState {
  from?: Location;
}

function describeFailure(error: unknown): string {
  if (error instanceof NetworkError) {
    return "Cannot reach the coordination backend. Confirm the API is running on the configured address.";
  }
  if (error instanceof ApiError) {
    return error.status === 401 ? "Invalid email or password." : error.message;
  }
  return "Sign-in failed unexpectedly. Check the browser console for details.";
}

export function LoginPage() {
  const { signIn } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const destination = (location.state as RedirectState | null)?.from?.pathname ?? "/dashboard";

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await signIn(email.trim(), password);
      navigate(destination, { replace: true });
    } catch (cause) {
      setError(describeFailure(cause));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="grid min-h-screen lg:grid-cols-[1.1fr_1fr]">
      <section className="relative hidden flex-col justify-between border-r border-navy-700 bg-navy-900 p-10 lg:flex">
        <div className="flex items-center gap-3">
          <Radio className="size-6 text-accent-400" aria-hidden />
          <span className="text-sm font-semibold uppercase tracking-[0.18em] text-ink-200">
            Disaster Response Platform
          </span>
        </div>

        <div className="max-w-md">
          <h1 className="text-3xl font-semibold leading-tight text-ink-100">
            Coordination that survives the loss of the network.
          </h1>
          <p className="mt-4 text-sm leading-relaxed text-ink-400">
            Field devices write to their own database first and reconcile with this command centre
            when a link exists. The backend is a peer, never a prerequisite.
          </p>

          <dl className="mt-8 grid grid-cols-3 gap-4 border-t border-navy-700 pt-6">
            {[
              ["Local-first", "Field datastore"],
              ["Deterministic", "Conflict merge"],
              ["Verifiable", "Signed records"],
            ].map(([term, detail]) => (
              <div key={term}>
                <dt className="text-sm font-medium text-ink-200">{term}</dt>
                <dd className="mt-0.5 text-xs text-ink-500">{detail}</dd>
              </div>
            ))}
          </dl>
        </div>

        <p className="font-mono text-xs text-ink-500">slice-2 · victims and triage</p>
      </section>

      <section className="flex items-center justify-center p-6">
        <div className="w-full max-w-sm">
          <div className="mb-8 lg:hidden">
            <Radio className="size-6 text-accent-400" aria-hidden />
          </div>

          <h2 className="text-xl font-semibold text-ink-100">Command centre sign-in</h2>
          <p className="mt-1.5 text-sm text-ink-400">
            Authorised coordination personnel only. All actions are attributable.
          </p>

          <form onSubmit={handleSubmit} className="mt-8 space-y-4" noValidate>
            <div>
              <label htmlFor="email" className="label-caps mb-1.5 block">
                Email
              </label>
              <input
                id="email"
                type="email"
                required
                autoComplete="username"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                className="w-full rounded-sm border border-navy-600 bg-navy-850 px-3 py-2 text-sm text-ink-100 placeholder:text-ink-500 focus:border-accent-500 focus:outline-none"
                placeholder="commander@drp.example"
              />
            </div>

            <div>
              <label htmlFor="password" className="label-caps mb-1.5 block">
                Password
              </label>
              <input
                id="password"
                type="password"
                required
                autoComplete="current-password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                className="w-full rounded-sm border border-navy-600 bg-navy-850 px-3 py-2 text-sm text-ink-100 placeholder:text-ink-500 focus:border-accent-500 focus:outline-none"
                placeholder="••••••••••••"
              />
            </div>

            {error && (
              <p
                role="alert"
                className="flex items-start gap-2 rounded-sm border border-critical/40 bg-critical/10 px-3 py-2 text-xs leading-relaxed text-critical"
              >
                <AlertTriangle className="mt-px size-4 shrink-0" aria-hidden />
                {error}
              </p>
            )}

            <button
              type="submit"
              disabled={submitting}
              className="flex w-full items-center justify-center gap-2 rounded-sm bg-accent-500 px-3 py-2 text-sm font-semibold text-white transition-colors hover:bg-accent-400 disabled:cursor-not-allowed disabled:opacity-60"
            >
              {submitting && <Loader2 className="size-4 animate-spin" aria-hidden />}
              {submitting ? "Authenticating" : "Sign in"}
            </button>
          </form>

          <p className="mt-6 border-t border-navy-700 pt-4 text-xs leading-relaxed text-ink-500">
            Demo accounts are created by <code className="font-mono text-ink-400">python -m app.db.seed</code>{" "}
            in the backend. Credentials come from your environment, never from source.
          </p>
        </div>
      </section>
    </div>
  );
}
