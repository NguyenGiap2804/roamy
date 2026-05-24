import { useCallback, useEffect, useMemo, useState } from 'react';

import { AdminApi, AuthExpiredError, QueryOptions } from './api';
import { AppShell, Section } from './components/AppShell';
import { DetailDrawer } from './components/DetailDrawer';
import { LoginScreen } from './components/LoginScreen';
import {
  ActivityPage,
  CategoriesPage,
  DrawerState,
  ErrorsPage,
  HealthPage,
  OverviewPage,
  PlacesPage,
  RequestsPage,
  SchedulesPage,
  SettingsPage,
  UploadsPage,
} from './pages/DashboardPages';
import type {
  AdminSession,
  ApiErrorLog,
  ApiRequestLog,
  Category,
  CategoryUpdatePayload,
  Health,
  ImageAsset,
  ImageHealthReport,
  ListResponse,
  Overview,
  Place,
  PlaceUpdatePayload,
  RetentionPreview,
  RetentionRunResult,
  Schedule,
  ScheduleUpdatePayload,
  SystemEvent,
} from './types';

type ListFilters = QueryOptions & {
  page: number;
  limit: number;
};

type ListState = {
  places: ListResponse<Place>;
  categories: ListResponse<Category>;
  schedules: ListResponse<Schedule>;
  activity: ListResponse<SystemEvent>;
  errors: ListResponse<ApiErrorLog>;
  requests: ListResponse<ApiRequestLog>;
  uploads: ListResponse<ImageAsset>;
};

const sessionKey = 'roamy-admin-session';
const refreshIntervalMs = 10_000;

const defaultFilters: ListFilters = {
  page: 1,
  limit: 20,
};

const emptyLists: ListState = {
  places: emptyList(),
  categories: emptyList(),
  schedules: emptyList(),
  activity: emptyList(),
  errors: emptyList(),
  requests: emptyList(),
  uploads: emptyList(),
};

export function App() {
  const [session, setSession] = useState<AdminSession | null>(() => {
    const raw = localStorage.getItem(sessionKey);
    return raw ? (JSON.parse(raw) as AdminSession) : null;
  });
  const [active, setActive] = useState<Section>('overview');
  const [overview, setOverview] = useState<Overview | null>(null);
  const [health, setHealth] = useState<Health | null>(null);
  const [lists, setLists] = useState<ListState>(emptyLists);
  const [referenceCategories, setReferenceCategories] = useState<Category[]>([]);
  const [referencePlaces, setReferencePlaces] = useState<Place[]>([]);
  const [filters, setFilters] = useState<Record<string, ListFilters>>({});
  const [query, setQuery] = useState('');
  const [autoRefreshEnabled, setAutoRefreshEnabled] = useState(true);
  const [lastUpdatedAt, setLastUpdatedAt] = useState<Date | null>(null);
  const [loadingSection, setLoadingSection] = useState<Section | null>(null);
  const [checkingImages, setCheckingImages] = useState(false);
  const [imageHealthReport, setImageHealthReport] =
    useState<ImageHealthReport | null>(null);
  const [retentionPreview, setRetentionPreview] =
    useState<RetentionPreview | null>(null);
  const [retentionResult, setRetentionResult] =
    useState<RetentionRunResult | null>(null);
  const [retentionRunning, setRetentionRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [drawer, setDrawer] = useState<DrawerState | null>(null);

  const api = useMemo(() => new AdminApi(session?.token ?? null), [session]);

  const logout = useCallback(() => {
    localStorage.removeItem(sessionKey);
    setSession(null);
    setDrawer(null);
  }, []);

  const handleError = useCallback(
    (loadError: unknown) => {
      if (loadError instanceof AuthExpiredError) {
        logout();
        return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
      }
      return loadError instanceof Error
        ? loadError.message
        : 'Không tải được dữ liệu';
    },
    [logout],
  );

  const sectionFilters = useCallback(
    (section: Section): ListFilters => ({
      ...defaultFilters,
      ...(filters[section] ?? {}),
    }),
    [filters],
  );

  const listQuery = useCallback(
    (section: Section): QueryOptions => ({
      ...sectionFilters(section),
      q: query,
    }),
    [query, sectionFilters],
  );

  const loadReferences = useCallback(async () => {
    if (!session) return;
    const [categories, places] = await Promise.all([
      api.categories({ limit: 100 }),
      api.places({ limit: 100 }),
    ]);
    setReferenceCategories(categories.items);
    setReferencePlaces(places.items);
  }, [api, session]);

  const loadCurrent = useCallback(
    async (silent = false) => {
      if (!session) return;
      if (!silent) {
        setLoadingSection(active);
      }
      setError(null);

      try {
        if (active === 'overview') {
          const [nextOverview, nextHealth] = await Promise.all([
            api.overview(),
            api.health(),
          ]);
          setOverview(nextOverview);
          setHealth(nextHealth);
        } else if (active === 'settings') {
          const [nextHealth, nextRetentionPreview] = await Promise.all([
            api.health(),
            api.retentionPreview(),
          ]);
          setHealth(nextHealth);
          setRetentionPreview(nextRetentionPreview);
        } else if (active === 'health') {
          setHealth(await api.health());
        } else if (active === 'places') {
          const places = await api.places(listQuery(active));
          setLists((current) => ({ ...current, places }));
        } else if (active === 'categories') {
          const categories = await api.categories(listQuery(active));
          setLists((current) => ({ ...current, categories }));
          setReferenceCategories(categories.items);
        } else if (active === 'schedules') {
          const schedules = await api.schedules(listQuery(active));
          setLists((current) => ({ ...current, schedules }));
        } else if (active === 'activity') {
          const activity = await api.activity(listQuery(active));
          setLists((current) => ({ ...current, activity }));
        } else if (active === 'errors') {
          const errors = await api.errors(listQuery(active));
          setLists((current) => ({ ...current, errors }));
        } else if (active === 'requests') {
          const requests = await api.requests(listQuery(active));
          setLists((current) => ({ ...current, requests }));
        } else if (active === 'uploads') {
          const uploads = await api.uploads(listQuery(active));
          setLists((current) => ({ ...current, uploads }));
        }

        if (active !== 'overview' && active !== 'health' && active !== 'settings') {
          setHealth(await api.health());
        }
        setLastUpdatedAt(new Date());
      } catch (loadError) {
        setError(handleError(loadError));
      } finally {
        setLoadingSection(null);
      }
    },
    [active, api, handleError, listQuery, session],
  );

  useEffect(() => {
    void loadReferences().catch((loadError) => setError(handleError(loadError)));
  }, [handleError, loadReferences]);

  useEffect(() => {
    void loadCurrent();
  }, [loadCurrent]);

  useEffect(() => {
    if (!session || !autoRefreshEnabled) return;
    const timer = window.setInterval(() => {
      if (document.visibilityState === 'visible') {
        void loadCurrent(true);
      }
    }, refreshIntervalMs);
    return () => window.clearInterval(timer);
  }, [autoRefreshEnabled, loadCurrent, session]);

  if (!session) {
    return (
      <LoginScreen
        api={api}
        onLogin={(nextSession) => {
          localStorage.setItem(sessionKey, JSON.stringify(nextSession));
          setSession(nextSession);
        }}
      />
    );
  }
  const activeSession = session;

  async function reloadAfterMutation() {
    await Promise.all([loadCurrent(true), loadReferences()]);
    setLastUpdatedAt(new Date());
  }

  async function updateItem(
    target: DrawerState,
    payload: PlaceUpdatePayload | CategoryUpdatePayload | ScheduleUpdatePayload,
  ) {
    try {
      if (target.kind === 'place') {
        await api.updatePlace(target.item.id, payload as PlaceUpdatePayload);
      } else if (target.kind === 'category') {
        await api.updateCategory(
          target.item.id,
          payload as CategoryUpdatePayload,
        );
      } else if (target.kind === 'schedule') {
        await api.updateSchedule(
          target.item.id,
          payload as ScheduleUpdatePayload,
        );
      }
      setDrawer(null);
      await reloadAfterMutation();
    } catch (mutationError) {
      setError(handleError(mutationError));
      throw mutationError;
    }
  }

  async function deleteItem(target: DrawerState) {
    try {
      if (target.kind === 'place') {
        await api.deletePlace(target.item.id);
      } else if (target.kind === 'category') {
        await api.deleteCategory(target.item.id);
      } else if (target.kind === 'schedule') {
        await api.deleteSchedule(target.item.id);
      }
      setDrawer(null);
      await reloadAfterMutation();
    } catch (mutationError) {
      setError(handleError(mutationError));
      throw mutationError;
    }
  }

  async function checkImages() {
    setCheckingImages(true);
    setError(null);
    try {
      const report = await api.checkImages({ limit: 100, q: query });
      setImageHealthReport(report);
      await loadCurrent(true);
    } catch (checkError) {
      setError(handleError(checkError));
    } finally {
      setCheckingImages(false);
    }
  }

  async function runRetention() {
    setRetentionRunning(true);
    setError(null);
    try {
      const result = await api.runRetention();
      setRetentionResult(result);
      setRetentionPreview(result);
      await loadCurrent(true);
    } catch (retentionError) {
      setError(handleError(retentionError));
    } finally {
      setRetentionRunning(false);
    }
  }

  function changeFilters(section: Section, patch: Partial<ListFilters>) {
    setFilters((current) => ({
      ...current,
      [section]: {
        ...defaultFilters,
        ...(current[section] ?? {}),
        ...patch,
      },
    }));
  }

  function changeQuery(value: string) {
    setQuery(value);
    if (active !== 'overview' && active !== 'health' && active !== 'settings') {
      changeFilters(active, { page: 1 });
    }
  }

  return (
    <AppShell
      active={active}
      autoRefreshEnabled={autoRefreshEnabled}
      health={health}
      lastUpdatedAt={lastUpdatedAt}
      query={query}
      session={activeSession}
      onActiveChange={setActive}
      onLogout={logout}
      onQueryChange={changeQuery}
      onRefresh={() => void loadCurrent()}
    >
      {error && <div className="error-banner">{error}</div>}
      {loadingSection && <div className="loading-bar" />}
      <section className="content">{renderActive()}</section>
      {drawer && (
        <DetailDrawer
          categories={referenceCategories}
          drawer={drawer}
          places={referencePlaces}
          onClose={() => setDrawer(null)}
          onDelete={deleteItem}
          onUpdate={updateItem}
        />
      )}
    </AppShell>
  );

  function renderActive() {
    if (active === 'overview') {
      return (
        <OverviewPage
          health={health}
          overview={overview}
          onOpen={setDrawer}
        />
      );
    }
    if (active === 'places') {
      return (
        <PlacesPage
          categories={referenceCategories}
          data={lists.places}
          filters={sectionFilters('places')}
          onFilterChange={(patch) => changeFilters('places', patch)}
          onOpen={setDrawer}
        />
      );
    }
    if (active === 'categories') {
      return (
        <CategoriesPage
          data={lists.categories}
          filters={sectionFilters('categories')}
          onFilterChange={(patch) => changeFilters('categories', patch)}
          onOpen={setDrawer}
        />
      );
    }
    if (active === 'schedules') {
      return (
        <SchedulesPage
          data={lists.schedules}
          filters={sectionFilters('schedules')}
          onFilterChange={(patch) => changeFilters('schedules', patch)}
          onOpen={setDrawer}
        />
      );
    }
    if (active === 'activity') {
      return (
        <ActivityPage
          data={lists.activity}
          filters={sectionFilters('activity')}
          onFilterChange={(patch) => changeFilters('activity', patch)}
          onOpen={setDrawer}
        />
      );
    }
    if (active === 'errors') {
      return (
        <ErrorsPage
          data={lists.errors}
          filters={sectionFilters('errors')}
          onFilterChange={(patch) => changeFilters('errors', patch)}
          onOpen={setDrawer}
        />
      );
    }
    if (active === 'requests') {
      return (
        <RequestsPage
          data={lists.requests}
          filters={sectionFilters('requests')}
          onFilterChange={(patch) => changeFilters('requests', patch)}
          onOpen={setDrawer}
        />
      );
    }
    if (active === 'uploads') {
      return (
        <UploadsPage
          data={lists.uploads}
          filters={sectionFilters('uploads')}
          imageHealthReport={imageHealthReport}
          isCheckingImages={checkingImages}
          onCheckImages={() => void checkImages()}
          onFilterChange={(patch) => changeFilters('uploads', patch)}
          onOpen={setDrawer}
        />
      );
    }
    if (active === 'health') {
      return <HealthPage health={health} />;
    }
    return (
      <SettingsPage
        autoRefreshEnabled={autoRefreshEnabled}
        health={health}
        retentionPreview={retentionPreview}
        retentionResult={retentionResult}
        retentionRunning={retentionRunning}
        session={activeSession}
        onRefresh={() => void loadCurrent()}
        onRunRetention={() => void runRetention()}
        onToggleAutoRefresh={setAutoRefreshEnabled}
      />
    );
  }
}

function emptyList<T>(): ListResponse<T> {
  return {
    total: 0,
    page: 1,
    limit: 20,
    totalPages: 0,
    items: [],
  };
}
