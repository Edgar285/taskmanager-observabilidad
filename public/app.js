// Frontend del gestor de tareas: consume la API REST del mismo servidor.
(() => {
  const $ = (sel) => document.querySelector(sel);
  const estado = { filtro: 'todas', categorias: [] };
  let temporizadorAviso;

  async function api(ruta, opciones = {}) {
    const res = await fetch(ruta, {
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      ...opciones
    });
    const cuerpo = await res.json().catch(() => ({ data: { mensaje: 'Respuesta no valida del servidor' } }));
    if (!res.ok) throw new Error((cuerpo.data && cuerpo.data.mensaje) || `Error ${res.status}`);
    return cuerpo.data;
  }

  function avisar(texto, esError = false) {
    const el = $('#aviso');
    el.textContent = texto;
    el.classList.toggle('error', esError);
    el.hidden = false;
    clearTimeout(temporizadorAviso);
    temporizadorAviso = setTimeout(() => { el.hidden = true; }, 3500);
  }

  function crear(tag, props = {}, hijos = []) {
    const el = document.createElement(tag);
    Object.entries(props).forEach(([k, v]) => {
      if (k === 'dataset') Object.assign(el.dataset, v);
      else if (k in el) el[k] = v;
      else el.setAttribute(k, v);
    });
    hijos.forEach((h) => el.append(h));
    return el;
  }

  async function cargarSalud() {
    try {
      const salud = await api('/api/health');
      $('[data-testid=estado-servicio]').textContent = salud.status === 'ok' ? 'Servicio en línea' : 'Servicio degradado';
      $('[data-testid=estado-servicio]').className = 'estado ' + (salud.status === 'ok' ? 'ok' : 'error');
      $('[data-testid=version]').textContent = `versión ${salud.version}`;
      $('[data-testid=commit]').textContent = `commit ${String(salud.commit).slice(0, 7)}`;
    } catch (e) {
      $('[data-testid=estado-servicio]').textContent = 'Sin conexión';
      $('[data-testid=estado-servicio]').className = 'estado error';
    }
  }

  async function cargarCategorias() {
    estado.categorias = await api('/api/categorias');
    const select = $('#select-categoria');
    const actual = select.value;
    select.replaceChildren(crear('option', { value: '', textContent: 'Sin categoría' }),
      ...estado.categorias.map((c) => crear('option', { value: String(c.id), textContent: c.nombre })));
    if ([...select.options].some((o) => o.value === actual)) select.value = actual;

    $('#lista-categorias').replaceChildren(...estado.categorias.map((c) =>
      crear('li', { className: 'categoria', dataset: { testid: 'categoria', id: c.id } }, [
        crear('span', { textContent: c.nombre }),
        crear('button', {
          type: 'button', className: 'btn-eliminar', textContent: 'Eliminar',
          'aria-label': `Eliminar categoría ${c.nombre}`, dataset: { testid: 'btn-eliminar-categoria' },
          onclick: () => eliminarCategoria(c)
        })
      ])));
  }

  async function cargarTareas() {
    const consulta = { todas: '', pendientes: '?completada=0', completadas: '?completada=1' }[estado.filtro];
    const tareas = await api('/api/tareas' + consulta);
    $('[data-testid=contador]').textContent = `${tareas.length} ${tareas.length === 1 ? 'tarea' : 'tareas'}`;
    $('[data-testid=lista-vacia]').hidden = tareas.length > 0;
    $('#lista-tareas').replaceChildren(...tareas.map((t) => {
      const hijos = [crear('span', { className: 'titulo', textContent: t.titulo, dataset: { testid: 'tarea-titulo' } })];
      if (t.categoria_nombre) hijos.push(crear('span', { className: 'etiqueta', textContent: t.categoria_nombre, dataset: { testid: 'tarea-categoria' } }));
      if (!t.completada) {
        hijos.push(crear('button', {
          type: 'button', className: 'btn-completar', textContent: 'Completar',
          'aria-label': `Completar ${t.titulo}`, dataset: { testid: 'btn-completar' }, onclick: () => completar(t)
        }));
      }
      hijos.push(crear('button', {
        type: 'button', className: 'btn-eliminar', textContent: 'Eliminar',
        'aria-label': `Eliminar ${t.titulo}`, dataset: { testid: 'btn-eliminar' }, onclick: () => eliminar(t)
      }));
      return crear('li', { className: 'tarea' + (t.completada ? ' completada' : ''), dataset: { testid: 'tarea', id: t.id } }, hijos);
    }));
  }

  async function completar(t) {
    try { await api(`/api/tareas/${t.id}/completar`, { method: 'PATCH' }); avisar('Tarea completada'); }
    catch (e) { avisar(e.message, true); }
    await cargarTareas();
  }

  async function eliminar(t) {
    try { await api(`/api/tareas/${t.id}`, { method: 'DELETE' }); avisar('Tarea eliminada'); }
    catch (e) { avisar(e.message, true); }
    await cargarTareas();
  }

  async function eliminarCategoria(c) {
    try { await api(`/api/categorias/${c.id}`, { method: 'DELETE' }); avisar('Categoría eliminada'); }
    catch (e) { avisar(e.message, true); }
    await cargarCategorias();
    await cargarTareas();
  }

  $('#form-tarea').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const titulo = $('#input-titulo').value;
    const categoria = $('#select-categoria').value;
    const cuerpo = { titulo };
    if (categoria) cuerpo.categoria_id = Number(categoria);
    try {
      await api('/api/tareas', { method: 'POST', body: JSON.stringify(cuerpo) });
      $('#input-titulo').value = '';
      avisar('Tarea agregada');
      await cargarTareas();
    } catch (e) { avisar(e.message, true); }
  });

  $('#form-categoria').addEventListener('submit', async (ev) => {
    ev.preventDefault();
    try {
      await api('/api/categorias', { method: 'POST', body: JSON.stringify({ nombre: $('#input-categoria').value }) });
      $('#input-categoria').value = '';
      avisar('Categoría agregada');
      await cargarCategorias();
    } catch (e) { avisar(e.message, true); }
  });

  document.querySelectorAll('.filtro').forEach((btn) => btn.addEventListener('click', async () => {
    estado.filtro = btn.dataset.filtro;
    document.querySelectorAll('.filtro').forEach((b) => b.classList.toggle('activo', b === btn));
    await cargarTareas();
  }));

  Promise.all([cargarSalud(), cargarCategorias()]).then(cargarTareas)
    .catch((e) => avisar(e.message, true))
    .finally(() => document.body.setAttribute('data-listo', '1'));
})();
